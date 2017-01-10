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
    H.start_link

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
    assert length(Quantum.jobs()) == 2 # includes the scheduler itself
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

    assert length(Quantum.jobs()) == 1 # the scheduler itself
    assert length(running_jobs(:cron)) == 0
  end

  # ================ run_at ================

  test "run_at scales dynos" do
    assert Scheduler.run_at("app", "dyno_type", "+5", nil, nil) == :ok
    scaled = H.scaled()
    assert length(scaled) == 1
    assert hd(scaled) == {"app", "dyno_type", "+5", 10, 15}
  end

  test "run_at observes min" do
    assert Scheduler.run_at("app", "dyno_type", "-15", 1, nil) == :ok
    scaled = H.scaled()
    assert length(scaled) == 1
    assert hd(scaled) == {"app", "dyno_type", "-15", 10, 1}
  end

  test "run_at observes max" do
    assert Scheduler.run_at("app", "dyno_type", "+15", nil, 12) == :ok
    scaled = H.scaled()
    assert length(scaled) == 1
    assert hd(scaled) == {"app", "dyno_type", "+15", 10, 12}
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
