defmodule Dynomizer.Scheduler do
  @moduledoc """
  Loads Dynomizer.{Heroku,HireFire}Schedule instances and schedules each for
  execution based on its schedule method (cron or at). Uses Quantum
  (https://github.com/c-rack/quantum-elixir) for cron-style scheduling and
  `Process.send_after` for at-style scheduling.

  `refresh` loads all schedules, cancels all modified jobs (as determined by
  the updated_at datetime), and schedules all new and changed schedules. It
  gets called once a minute.

  `run` handles execution of a single job.

  The state is a two-element tuple. The first element is the module used to
  actually scale Heroku dynos, and is whatever was passed in to
  `start_link`. The second element is a tuple of two maps, the first for
  Heroku and the second for Hirefire. Each map's keys are schedule ids and
  values are tuples of the form `{schedule, arg}`. `arg` is whatever term
  can be used to identify and stop the job: either a Quantum job name or a
  `Process` timer, depending on the schedule's method.
  """

  # one minute
  @refresh_interval_millisecs 60 * 1000

  use GenServer
  require Logger
  alias Dynomizer.Repo
  alias Dynomizer.HerokuSchedule, as: HS
  alias Dynomizer.HirefireSchedule, as: HFS

  # ================ public ================

  @doc """
  Pass in the module that will be used to scale dynos. Typically that will
  be `Dynomizer.Heroku`, but the test environment uses a mock.
  """
  def start_link(heroku_scaler_module, hirefire_scaler_module) do
    GenServer.start_link(
      __MODULE__,
      {{heroku_scaler_module, hirefire_scaler_module}, {%{}, %{}}},
      name: __MODULE__
    )
  end

  def init(state) do
    schedule_refresh()
    {:ok, state}
  end

  @doc """
  Normally this method is called by the jobs that are scheduled, and is not
  called by any other part of the system.
  """
  def run(schedule) do
    GenServer.call(__MODULE__, {:run, schedule})
  end

  @doc "Run one refresh. Used for testing."
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  @doc """
  Return running schedules tuple containing two maps, first for Heroku and
  next for HireFire. Used for testing.
  """
  def running do
    GenServer.call(__MODULE__, :running)
  end

  # ================ handlers ================

  # Run a single schedule.
  def handle_call({:run, schedule}, _from, {scalers, _} = state) do
    run_schedule(schedule, scalers)
    {:reply, :ok, state}
  end

  # For testing
  def handle_call(:refresh, _from, {scalers, running}) do
    {:reply, :ok, {scalers, reschedule(running)}}
  end

  # For testing
  def handle_call(:running, _from, {_, running} = state) do
    {:reply, running, state}
  end

  # Target of `schedule_refresh/0`.
  def handle_info(:refresh, {scalers, running}) do
    new_state = {scalers, reschedule(running)}
    schedule_refresh()
    {:noreply, new_state}
  end

  # Target of `Process.send_after`.
  def handle_info({:run, schedule}, {scalers, _} = state) do
    run_schedule(schedule, scalers)
    {:noreply, state}
  end

  def terminate(reason, {_, {heroku, hirefire}}) do
    stop_jobs(heroku)
    stop_jobs(hirefire)
    if reason != :shutdown, do: Logger.info("Dynomizer.Scheduler.terminate: #{inspect(reason)}")
  end

  # ================ helpers ================

  def schedule_refresh() do
    Process.send_after(self(), :refresh, @refresh_interval_millisecs)
  end

  @doc """
  Given a schedule string return either :cron or :at.

  ## Examples

      iex> alias Dynomizer.Scheduler, as: S
      iex> S.method("3 5 * * *")
      :cron
      iex> alias Dynomizer.Scheduler, as: S
      iex> S.method("2017-01-15 12:34:56")
      :at
  """
  def method(str) do
    if str |> String.trim() |> String.split() |> length == 5 do
      :cron
    else
      :at
    end
  end

  # Loads schedules and sets their method virtual fields.
  defp load_schedules do
    method_loader = fn s -> %{s | method: method(s)} end

    hs =
      HS
      |> Repo.all()
      |> Enum.map(method_loader)

    hfs =
      HFS
      |> Repo.all()
      |> Repo.preload(:numeric_parameters)
      |> Enum.map(method_loader)

    {hs, hfs}
  end

  # Stops deleted jobs, starts new jobs, and restarts modified ones. Returns
  # a map of the new set of running jobs.
  defp reschedule({old_heroku_scheds, old_hirefire_scheds}) do
    get_sched = fn {s, _} -> s end
    old_h = old_heroku_scheds |> Map.values() |> Enum.map(get_sched)
    old_hf = old_hirefire_scheds |> Map.values() |> Enum.map(get_sched)

    {new_h, new_hf} = load_schedules()

    {new, mod, del, unch} = partition(old_h, new_h, &HS.partition_comparator/2)
    reschedule(new, mod, del, unch, old_heroku_scheds)

    {new, mod, del, unch} = partition(old_hf, new_hf, &HFS.partition_comparator/2)
    reschedule(new, mod, del, unch, old_hirefire_scheds)
  end

  # Short-circuit the most common case: nothing has changed.
  defp reschedule([], [], [], _, running), do: running

  defp reschedule(new, mod, del, unch, running) do
    # Stop deleted and modified jobs
    running
    |> Map.take(ids(del ++ mod))
    |> stop_jobs

    # Start new and modified jobs
    started_map = start_jobs(new ++ mod)

    running
    |> Map.take(ids(unch))
    |> Map.merge(started_map)
  end

  defp run_schedule(%HS{} = schedule, {heroku_scaler, _}) do
    Logger.info("running #{inspect(schedule)}")
    heroku_scaler.scale(schedule)
  end

  defp run_schedule(%HFS{} = schedule, {_, hirefire_scaler}) do
    Logger.info("running #{inspect(schedule)}")
    hirefire_scaler.scale(schedule)
  end

  # Start each scheduled job and return a state map.
  defp start_jobs(schedules) do
    schedules
    |> Enum.map(&{&1.id, {&1, start_job(&1)}})
    |> Enum.into(%{})
  end

  # Starts a job and returns whatever term can be used to identify and stop
  # the job.
  defp start_job(%HS{} = s) do
    start_job(s.method, s, s.id, s.schedule)
  end

  defp start_job(%HFS{} = s) do
    start_job(s.method, s, s.id, s.schedule)
  end

  defp start_job(:cron, sched, id, schedule_str) do
    name = String.to_atom("job#{id}")

    job = %Quantum.Job{
      schedule: schedule_str,
      task: {__MODULE__, :run},
      args: [sched]
    }

    :ok = Quantum.add_job(name, job)
    name
  end

  defp start_job(:at, sched, _id, at_str) do
    at =
      with {:ok, dt, 0} <- DateTime.from_iso8601(at_str <> "Z") do
        dt |> DateTime.to_unix(:milliseconds)
      end

    now = DateTime.utc_now() |> DateTime.to_unix(:milliseconds)
    wait = at - now

    if wait > 0 do
      Process.send_after(self(), {:run, sched}, wait)
    else
      nil
    end
  end

  # Take a map (state or a subset of it) and stops all of those jobs.
  defp stop_jobs(running) do
    running
    |> Map.values()
    |> Enum.each(fn {s, arg} -> stop_job(s.method, arg) end)
  end

  defp stop_job(:cron, name) do
    Quantum.delete_job(name)
  end

  defp stop_job(:at, nil) do
    # nop
  end

  defp stop_job(:at, timer) do
    # It's OK if the timer has already been sent.
    Process.cancel_timer(timer)
  end

  # Given `oldies` and `newbies`, return a tuple of lists `{created, updated,
  # deleted, unchanged}`. Used by the `Dynamo.Scheduler` to determine what has
  # changed.
  defp partition(oldies, newbies, comparator_func) do
    # Create maps from ids to schedules.
    mapify = fn xs -> xs |> Enum.map(&{&1.id, &1}) |> Enum.into(%{}) end
    old_m = mapify.(oldies)
    new_m = mapify.(newbies)
    old_ids = Map.keys(old_m)
    new_ids = Map.keys(new_m)

    deleted_ids = old_ids -- new_ids
    created_ids = new_ids -- old_ids
    common_ids = MapSet.intersection(MapSet.new(old_ids), MapSet.new(new_ids))

    {unchanged_ids, updated_ids} =
      common_ids
      |> Enum.partition(&comparator_func.(Map.get(old_m, &1), Map.get(new_m, &1)))

    take_scheds = fn m, ids -> m |> Map.take(ids) |> Map.values() end

    {
      take_scheds.(new_m, created_ids),
      take_scheds.(new_m, updated_ids),
      take_scheds.(old_m, deleted_ids),
      take_scheds.(old_m, unchanged_ids)
    }
  end

  defp ids(schedules), do: schedules |> Enum.map(& &1.id)
end
