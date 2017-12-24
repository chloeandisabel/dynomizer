defmodule Dynomizer.HirefireScheduleControllerTest do
  use Dynomizer.ConnCase

  alias Dynomizer.HirefireSchedule, as: HFS

  @valid_attrs %{
    application: "appname",
    description: "some content",
    dyno_type: "web",
    manager_type: "Web.NewRelic.V2.ResponseTime",
    schedule: "30 4 * * * *",
    enabled: true,
    decrementable: true,
    state: nil
  }
  @valid_get_attrs Map.take(@valid_attrs, [
                     :application,
                     :description,
                     :dyno_type,
                     :manager_type,
                     :schedule
                   ])
  @invalid_attrs %{}

  test "lists all entries on index", %{conn: conn} do
    conn = get(conn, schedule_path(conn, :index))
    assert html_response(conn, 200) =~ "Listing schedules"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get(conn, schedule_path(conn, :new))
    assert html_response(conn, 200) =~ "New schedule"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    schedule = HFS.new_changeset(%HFS{}, @valid_attrs) |> Ecto.Changeset.apply_changes()
    conn = post(conn, schedule_path(conn, :create), schedule: form_attrs(schedule))
    assert redirected_to(conn) == schedule_path(conn, :index)
    assert Repo.get_by(HFS, @valid_get_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post(conn, schedule_path(conn, :create), schedule: @invalid_attrs)
    assert html_response(conn, 200) =~ "New schedule"
  end

  test "shows chosen resource", %{conn: conn} do
    schedule = Repo.insert!(HFS.new_changeset(%HFS{}, @valid_attrs))
    conn = get(conn, schedule_path(conn, :show, schedule))
    assert html_response(conn, 200) =~ "Show schedule"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent(404, fn ->
      get(conn, schedule_path(conn, :show, -1))
    end)
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    schedule = Repo.insert!(HFS.new_changeset(%HFS{}, @valid_attrs))
    conn = get(conn, schedule_path(conn, :edit, schedule))
    assert html_response(conn, 200) =~ "Edit schedule"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    schedule = Repo.insert!(HFS.new_changeset(%HFS{}, @valid_attrs))
    conn = put(conn, schedule_path(conn, :update, schedule), schedule: form_attrs(schedule))
    assert redirected_to(conn) == schedule_path(conn, :show, schedule)
    assert Repo.get_by(HFS, @valid_get_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    schedule = Repo.insert!(HFS.new_changeset(%HFS{}, @valid_attrs))
    params = form_attrs(schedule) |> Map.delete(:application)
    conn = put(conn, schedule_path(conn, :update, schedule), schedule: params)
    assert html_response(conn, 302) =~ "redirected"
  end

  test "deletes chosen resource", %{conn: conn} do
    schedule = Repo.insert!(HFS.new_changeset(%HFS{}, @valid_attrs))
    conn = delete(conn, schedule_path(conn, :delete, schedule))
    assert redirected_to(conn) == schedule_path(conn, :index)
    refute Repo.get(HFS, schedule.id)
  end

  test "shows applications returned by hirefire", %{conn: conn} do
    conn = get(conn, schedule_path(conn, :snapshot_form))
    assert html_response(conn, 200) =~ ~r/app1.*app2/
  end

  defp form_attrs(schedule) do
    @valid_attrs
    |> Map.put(:id, schedule.id)
    |> Map.put(:numeric_parameters, schedule.numeric_parameters |> Enum.map(&Map.from_struct/1))
  end
end
