defmodule Dynomizer.Scheduler do
  @moduledoc """
  Loads Dynomizer.Schedule instances and schedules each for execution based
  on its schedule method (cron or at). Uses Quantum
  (https://github.com/c-rack/quantum-elixir) for cron-style scheduling and
  `Process.send_after` for at-style scheduling.

 `refresh` loads all schedules, cancels all modified jobs (as determined by
  the updated_at datetime), and schedules all new and changed schedules. It
  gets called once a minute.

 `run` handles execution of a single job.

  The state is a two-element tuple. The first element is the module used to
  actually scale Heroku dynos, and is whatever was passed in to
  `start_link`. The second element is a map whose keys are schedule ids and
  values are tuples of the form `{schedule, arg}`. `arg` is whatever term
  can be used to identify and stop the job: either a Quantum job name or a
  `Process` timer, depending on the schedule's method.
  """

  @refresh_interval_millisecs 60 * 1000 # one minute

  use GenServer
  require Logger
  alias Dynomizer.{Repo, Schedule}

  # ================ public ================

  @doc """
  Pass in the module that will be used to scale dynos. Typically that will
  be `Dynomizer.Heroku`, but the test environment uses a mock.
  """
  def start_link(scaler_module) do
    GenServer.start_link(__MODULE__, {scaler_module, %{}}, name: __MODULE__)
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

  @doc "Return running schedules map. Used for testing."
  def running do
    GenServer.call(__MODULE__, :running)
  end

  # ================ handlers ================

  # Run a single schedule.
  def handle_call({:run, schedule}, _from, {scaler, _} = state) do
    run_schedule(schedule, scaler)
    {:reply, :ok, state}
  end

  # For testing
  def handle_call(:refresh, _from, {scaler, running}) do
    {:reply, :ok, {scaler, reschedule(running)}}
  end

  # For testing
  def handle_call(:running, _from, {_, running} = state) do
    {:reply, running, state}
  end

  # Target of `schedule_refresh/0`.
  def handle_info(:refresh, {scaler, running}) do
    new_state = {scaler, reschedule(running)}
    schedule_refresh()
    {:noreply, new_state}
  end

  # Target of `Process.send_after`.
  def handle_info({:run, schedule}, {scaler, _} = state) do
    run_schedule(schedule, scaler)
    {:noreply, state}
  end

  def terminate(reason, {_, running}) do
    stop_jobs(running)
    if reason != :shutdown, do: Logger.info("Dynomizer.Scheduler.terminate: #{inspect reason}")
  end

  # ================ helpers ================

  def schedule_refresh() do
    Process.send_after(self(), :refresh, @refresh_interval_millisecs)
  end

  # Loads schedules and sets their method virtual fields.
  defp load_schedules do
    Schedule
    |> Repo.all
    |> Enum.map(fn s -> %{s | method: Schedule.method(s)} end)
  end

  # Stops deleted jobs, starts new jobs, and restarts modified ones. Returns
  # a map of the new set of running jobs.
  defp reschedule(running) do
    old_schedules = running |> Map.values |> Enum.map(fn {s, _} -> s end)
    new_schedules = load_schedules()
    {new, mod, del, unch} = Schedule.partition(old_schedules, new_schedules)
    reschedule(new, mod, del, unch, running)
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

  defp run_schedule(schedule, scaler) do
    Logger.info "running #{inspect schedule}"
    scaler.scale(schedule)
  end

  # Start each scheduled job and return a state map.
  defp start_jobs(schedules) do
    schedules
    |> Enum.map(&({&1.id, {&1, start_job(&1)}}))
    |> Enum.into(%{})
  end

  # Starts a job and returns whatever term can be used to identify and stop
  # the job.
  defp start_job(%Schedule{method: :cron} = s) do
    name = String.to_atom("job#{s.id}")

    job = %Quantum.Job{
      schedule: s.schedule,
      task: {__MODULE__, :run},
      args: [s],
    }
    :ok = Quantum.add_job(name, job)
    name
  end
  defp start_job(%Schedule{method: :at} = s) do
    at = Schedule.to_unix_milliseconds(s)
    now = DateTime.utc_now |> DateTime.to_unix(:milliseconds)
    wait = at - now
    if wait > 0 do
      Process.send_after(self(), {:run, s}, wait)
    else
      nil
    end
  end

  # Take a map (state or a subset of it) and stops all of those jobs.
  defp stop_jobs(running) do
    running
    |> Map.values
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

  defp ids(schedules), do: schedules |> Enum.map(&(&1.id))
end
