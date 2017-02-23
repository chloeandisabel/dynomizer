defmodule Dynomizer.ScheduleTest do
  use Dynomizer.ModelCase
  doctest Dynomizer.Schedule

  alias Dynomizer.Schedule

  @valid_base_attrs %{application: "appname", description: "some content",
                      dyno_type: "web",
                      manager_type: "Manager::Web::NewRelic::V2::ResponseTime",
                      enabled: true, decrementable: true,
                      numeric_parameters: [
                        %{name: "minimum", rule: "+5", min: 1, max: 100},
                        %{name: "maximum", rule: "+5", min: 1, max: 100},
                        %{name: "ratio", rule: "+20", min: 0, max: 100}
                      ],
                      state: nil}
  @valid_cron_attrs Map.merge(@valid_base_attrs, %{schedule: "30 4 * * *"})
  @valid_at_attrs Map.merge(@valid_base_attrs, %{schedule: "2017-01-04 20:57:43"})
  @invalid_attrs %{}

  test "changeset with valid attributes for cron" do
    changeset = Schedule.changeset(%Schedule{}, @valid_cron_attrs)
    assert changeset.valid?
  end

  test "changeset with valid attributes for at" do
    changeset = Schedule.changeset(%Schedule{}, @valid_at_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Schedule.changeset(%Schedule{}, @invalid_attrs)
    refute changeset.valid?
  end

  # {created, updated, deleted, unchanged}

  test "partition when no oldies or newbies" do
    assert Schedule.partition([], []) == {[], [], [], []}
  end

  test "partition when no oldies" do
    s = %Schedule{id: 1, updated_at: DateTime.utc_now()}
    assert Schedule.partition([], [s]) == {[s], [], [], []}
  end

  test "partition when no newbies" do
    s = %Schedule{id: 1, updated_at: DateTime.utc_now()}
    assert Schedule.partition([s], []) == {[], [], [s], []}
  end

  test "unchanged" do
    s = %Schedule{id: 1, updated_at: DateTime.utc_now()}
    assert Schedule.partition([s], [s]) == {[], [], [], [s]}
  end

  test "all four" do
    # For purposes of testing, updated_at doesn't need to be a DateTime
    created = %Schedule{id: 1, updated_at: 0}
    deleted = %Schedule{id: 2, updated_at: 0}
    unchanged = %Schedule{id: 3, updated_at: 0}
    changed_1 = %Schedule{id: 4, updated_at: 0}
    changed_2 = %Schedule{id: 4, updated_at: 1}

    oldies = [deleted, unchanged, changed_1]
    newbies = [created, unchanged, changed_2]
    assert Schedule.partition(oldies, newbies) == {[created], [changed_2], [deleted], [unchanged]}
  end
end
