defmodule Dynomizer.Scheduler do
  @moduledoc """
  Loads Dynomizer.Schedule instances and schedules each for execution based
  on its schedule method (cron or at). Uses Quantum
  (https://github.com/c-rack/quantum-elixir) for cron-style scheduling and
  `Process.send_after` for at-style scheduling.

 `refresh` loads all schedules, cancels all modified jobs (as determined by
  the updated_at datetime), and schedules all new and changed schedules. In
  the config files we tell Quantum to schedule execution of `refresh` at
  regular one-minute intervals.

 `run_at` handles execution of a single job.

  The state is a two-element tuple. The first element is the module used to
  actually scale Heroku dynos, and is whatever was passed in to
  `start_link`. The second element is a map whose keys are schedule ids and
  values are tuples of the form `{schedule, arg}`. `arg` is whatever term
  can be used to identify and stop the job: either a Quantum job name or a
  `Process` timer, depending on the schedule's method.
  """

  use GenServer
  require Logger
  alias Dynomizer.{Repo, Schedule}

  # ================ public ================

  @doc """
  Pass in the module that will be used to scale dynos. Typically that will
  be `Dynomizer.Heroku`, but the test environment uses a mock.
  """
  def start_link(scaler_module) do
    result = GenServer.start_link(__MODULE__, {scaler_module, %{}}, name: __MODULE__)
    :ok = Quantum.add_job("1 * * *", &refresh/0)
    result
  end

  @doc """
  Called periodically to load all schedules, cancel all modified jobs (as
  determined by the updated_at datetime), and (re)schedule all new and
  changed schedules.

  In the config files we tell Quantum to schedule execution of `refresh` at
  regular one-minute intervals.
  """
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  @doc """
  Normally this method is called by the jobs that are scheduled, and is not
  called by any other part of the system.
  """
  def run_at(app, dyno_type, rule) do
    GenServer.call(__MODULE__, {:run_at, app, dyno_type, rule})
  end

  @doc "Return running schedules map. Used for testing."
  def running do
    GenServer.call(__MODULE__, :running)
  end

  @doc """
  Only used for testing, along with a mock Heroku API module. Do NOT bother
  calling this any other time. It's harmless and you'll get back `nil`.
  """
  def scaled do
    GenServer.call(__MODULE__, :scaled)
  end

  # ================ handlers ================

  def handle_call(:refresh, _from, {scaler, running}) do
    Logger.debug "Dynomizer.Scheduler#refreshing"
    {:reply, :ok, {scaler, reschedule(running)}}
  end

  def handle_call({:run_at, app, dyno_type, rule}, _from, {scaler, _} = state) do
    scaler.scale(app, dyno_type, rule)
    {:reply, :ok, state}
  end

  def handle_call(:running, _from, {_, running} = state) do
    {:reply, running, state}
  end

  def handle_call(:scaled, _from, {scaler, _} = state) do
    result = if scaler.__info__(:functions)[:scaled], do: scaler.scaled, else: nil
    {:reply, result, state}
  end

  def terminate(reason, {_, running}) do
    stop_jobs(running)
    if reason != :shutdown, do: Logger.info("Dynomizer.Scheduler.terminate: #{inspect reason}")
  end

  # ================ helpers ================

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

    # job = {s.schedule, &run_at/3, [s.application, s.dyno_type, s.rule]}
    job = %Quantum.Job{
      schedule: s.schedule,
      task: {__MODULE__, :run_at}, # required
      args: [s.application, s.dyno_type, s.rule],
    }
    :ok = Quantum.add_job(name, job)
    name
  end
  defp start_job(%Schedule{method: :at} = s) do
    at = Schedule.to_unix_milliseconds(s)
    now = DateTime.utc_now |> DateTime.to_unix(:milliseconds)
    if at >= now do
      msg = {:run_at, s.application, s.dyno_type, s.rule}
      Process.send_after(__MODULE__, msg, at, abs: true)
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
