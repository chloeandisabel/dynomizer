defmodule Dynomizer.Scheduler do
  use GenServer
  require Logger
  alias Dynomizer.{Repo, Schedule, Heroku}

  # ================ public ================

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  # ================ handlers ================

  def handle_call(:refresh, _from, state) do
    Logger.debug "Dynomizer.Scheduler#refreshing"
    schedules = Repo.all(Schedule)
    stop_all_jobs(state)
    new_state = start_all_jobs(schedules)
    {:reply, :ok, new_state}
  end

  def handle_call({:run_at, app, dyno_type, rule}, _from, state) do
    {:reply, Heroku.scale(app, dyno_type, rule), state}
  end

  def terminate(reason, state) do
    stop_all_jobs(state)
    if reason != :shutdown, do: Logger.info("Dynomizer.Scheduler.terminate: #{inspect reason}")
  end

  # ================ helpers ================

  defp stop_all_jobs(state) do
    state
    |> Enum.each(&stop_job/1)
  end

  defp start_all_jobs(schedules) do
    schedules
    |> Enum.map(&start_job/1)
  end

  defp start_job(%Schedule{schedule_method: "cron"} = s) do
    # TODO handle error
    name = job_name(s)
    Quantum.add_job(name, job(s))
    {name, :cron, nil}
  end
  defp start_job(%Schedule{schedule_method: "at"} = s) do
    # TODO handle error
    name = job_name(s)
    msg = {:run_at, s.application, s.dyno_type, s.rule}
    case wait_millisecs(s.schedule) do
      {:ok, delay} ->
        timer = Process.send_after(__MODULE__, msg, delay)
        {name, :at, timer}
      :error ->
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
    Process.cancel_timer(timer)
  end

  defp job_name(%Schedule{id: id}) do
    "job#{id}"
  end

  defp job(s) do
    {s.schedule, &Heroku.scale/3, [s.application, s.dyno_type, s.rule]}
  end

  # Returns {:ok, millisecs} if schedule string is not in the past. Else
  # returns :error.
  defp wait_millisecs(schedule) do
    now = NaiveDateTime.utc_now()
    then = Schedule.naive_datetime(schedule)
    diff = NaiveDateTime.diff(then, now, :microsecond)
    if diff >= 0 do
      {:ok, diff}
    else
      :error
    end
  end
end
