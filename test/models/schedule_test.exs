defmodule Dynomizer.ScheduleTest do
  use Dynomizer.ModelCase

  alias Dynomizer.Schedule

  @valid_cron_attrs %{application: "appname", description: "some content", dyno_type: "web", rule: "+5", schedule: "30 4 * * *", schedule_method: "cron", state: nil}
  @valid_at_attrs %{application: "appname", description: "some content", dyno_type: "web", rule: "+5", schedule: "2017-01-04 20:57:43", schedule_method: "at", state: nil}
  @valid_form_attrs %{application: "appname", description: "some content", dyno_type: "web", rule: "+5", schedule: "30 4 * * *"}
  @invalid_attrs %{}

  test "changeset with valid attributes for cron" do
    changeset = Schedule.changeset(%Schedule{}, @valid_cron_attrs)
    assert changeset.valid?
  end

  test "changeset with valid attributes for at" do
    changeset = Schedule.changeset(%Schedule{}, @valid_at_attrs)
    assert changeset.valid?
  end

  test "changeset with valid form attributes" do
    changeset = Schedule.schedule_changeset(%Schedule{}, @valid_form_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Schedule.changeset(%Schedule{}, @invalid_attrs)
    refute changeset.valid?
  end
end
