defmodule Dynomizer.MockHeroku do
  @moduledoc """
  Testing version of Heroku API.
  """

  alias Dynomizer.Rule

  @doc "Clear all memory of calls to scale."
  def reset do
    Process.delete(__MODULE__)
  end

  def scaled do
    Process.get(__MODULE__, []) |> Enum.reverse
  end

  def scale(app, dyno_type, rule) do
    curr_count = curr_count(app, dyno_type)
    new_count = Rule.apply(rule, curr_count)
    remember(app, dyno_type, rule, curr_count, new_count)
  end

  def curr_count(_, _), do: 10

  defp remember(app, dyno_type, rule, curr_count, new_count) do
    entries = Process.get(__MODULE__, [])
    entry = {app, dyno_type, rule, curr_count, new_count}
    Process.put(__MODULE__, [entry|entries])
  end
end

# ================================================================

defmodule Dynomizer.SchedulerTest do
  use ExUnit.Case
  doctest Dynomizer.Scheduler
  alias Dynomizer.{Scheduler, Schedule, Repo}
  alias Dynomizer.MockHeroku, as: H

  @future_at NaiveDateTime.utc_now |> NaiveDateTime.add(1_000_000, :seconds) |> to_string
  @past_at NaiveDateTime.utc_now |> NaiveDateTime.add(-1_000_000, :seconds) |> to_string
  @cron_schedule %{application: "app", description: "some content", dyno_type: "web", rule: "+5", schedule: "30 4 * * *", state: nil}
  @at_schedule %{application: "app", description: "some content", dyno_type: "web", rule: "+10", schedule: @future_at, state: nil}
  @past_at_schedule %{application: "app", description: "some content", dyno_type: "web", rule: "+15", schedule: @past_at, state: nil}

  setup context do
    H.reset

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    attrs = 
      context[:attrs] || [@cron_schedule, @at_schedule, @past_at_schedule]
    schedules =
      attrs
      |> Enum.map(fn a ->
           Schedule.changeset(%Schedule{}, a) |> Repo.insert!
         end)
    Scheduler.refresh
    {:ok, [schedules: schedules]}
  end

  # ================ refresh ================

  test "refresh starts scheduled jobs" do
    running = Scheduler.running
    assert running |> Map.keys |> length == 3
  end

  test "refresh starts one :cron job" do
    assert length(running_jobs(:cron)) == 1
    assert length(Quantum.jobs) == 1
  end

  test "refresh starts two :at jobs" do
    assert length(running_jobs(:at)) == 2
  end

  test "refresh ignores past :at job" do
    {started_args, ignored_args} =
      running_jobs(:at)
      |> Enum.map(fn {_, arg} -> arg end)
      |> Enum.partition(&(&1 != nil))
    assert length(started_args) == 1
    assert length(ignored_args) == 1
  end

  test "refresh registers :cron schedules with Quantum" do
    {cron, arg} = running_jobs(:cron) |> hd
    assert cron.schedule == @cron_schedule.schedule
    assert Quantum.find_job(arg) != nil
  end

  test "refresh registers :at schedules with Process" do
    {_, at_arg} =
      running_jobs(:at)
      |> Enum.filter(fn {_, arg} -> arg != nil end)
      |> hd
    assert Process.read_timer(at_arg) > 0
  end

  test "refresh deletes deleted schedules" do
    {cron_schedule, _} = running_jobs(:cron) |> hd
    Repo.delete!(cron_schedule)
    Scheduler.refresh

    assert length(Quantum.jobs()) == 0
    assert length(running_jobs(:cron)) == 0
  end

  # ================ run_at ================

  test "run_at scales dynos" do
    assert Scheduler.run_at("app", "dyno_type", "+5") == :ok
    scaled = Scheduler.scaled()
    assert length(scaled) == 1
    assert hd(scaled) == {"app", "dyno_type", "+5", 10, 15}
  end

  # ================ helpers ================

  # Returns the list of running {schedule, arg} jobs that are of the given
  # method (:cron or :at).
  defp running_jobs(method) do
      Scheduler.running
      |> Enum.filter(fn {_, {s, _}} -> Schedule.method(s) == method end)
      |> Enum.map(fn {_, schedule_and_arg} -> schedule_and_arg end)
  end
end
