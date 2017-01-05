defmodule Dynomizer.Scheduler do
  use GenServer
  require Logger
  alias Dynomizer.{Repo, Schedule, Heroku}

  # ================ public ================

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def run_at(app, dyno_type, rule) do
    GenServer.call(__MODULE__, {:run_at, app, dyno_type, rule})
  end

  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  # ================ handlers ================

  def handle_call(:refresh, _from, state) do
    Logger.debug "Dynomizer.Scheduler#refreshing"
    stop_all_jobs(state)
    new_state =
      Schedule
      |> Repo.all
      |> start_all_jobs
    {:reply, :ok, new_state}
  end

  def handle_call({:run_at, app, dyno_type, rule}, _from, state) do
    Heroku.scale(app, dyno_type, rule)
    {:reply, :ok, state}
  end

  def terminate(reason, state) do
    stop_all_jobs(state)
    if reason != :shutdown, do: Logger.info("Dynomizer.Scheduler.terminate: #{inspect reason}")
  end

  # ================ helpers ================

  defp start_all_jobs(schedules) do
    schedules
    |> Enum.map(&start_job/1)
  end

  defp stop_all_jobs(state) do
    state
    |> Enum.each(&stop_job/1)
  end

  # Dispatch to start_job/3 based on schedule method.
  defp start_job(s) do
    start_job(s, Schedule.method(s), job_name(s))
  end

  defp start_job(s, :cron, name) do
    job = {s.schedule, &run_at/3, [s.application, s.dyno_type, s.rule]}
    Quantum.add_job(name, job)
    {name, :cron, nil}
  end
  defp start_job(s, :at, name) do
    at = Schedule.to_unix_milliseconds(s)
    now = DateTime.utc_now |> DateTime.to_unix(:milliseconds)
    if at >= now do
      msg = {:run_at, s.application, s.dyno_type, s.rule}
      timer = Process.send_after(__MODULE__, msg, at, abs: true)
      {name, :at, timer}
    else
      {name, :at, nil}
    end
  end

  defp stop_job({name, :cron, _}) do
    Quantum.delete_job(name)
  end
  defp stop_job({_, :at, nil}) do
    # nop
  end
  defp stop_job({_, :at, timer}) do
    # It's OK if the timer has already been sent.
    Process.cancel_timer(timer)
  end

  defp job_name(%Schedule{id: id}) do
    "job#{id}"
  end
end
