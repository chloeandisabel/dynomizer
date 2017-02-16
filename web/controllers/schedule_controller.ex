defmodule Dynomizer.ScheduleController do
  use Dynomizer.Web, :controller
  plug :authorize

  alias Dynomizer.{Schedule, Auth}
  alias Apprentice.HireFire.Manager

  def index(conn, _params) do
    schedules = Repo.all(from s in Schedule, order_by: s.id)
    render(conn, "index.html", schedules: schedules)
  end

  def new(conn, _params) do
    changeset = Schedule.create_changeset(%Schedule{})
    render(conn, "new.html", changeset: changeset, form_fields: form_fields())
  end

  def create(conn, %{"schedule" => schedule_params}) do
    changeset = Schedule.changeset(%Schedule{}, schedule_params)

    case Repo.insert(changeset) do
      {:ok, _schedule} ->
        conn
        |> put_flash(:info, "Schedule created successfully.")
        |> redirect(to: schedule_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset, form_fields: form_fields())
    end
  end

  def show(conn, %{"id" => id}) do
    schedule = Repo.get!(Schedule, id) |> Repo.preload(:numeric_parameters)
    render(conn, "show.html", schedule: schedule, form_fields: form_fields())
  end

  def edit(conn, %{"id" => id}) do
    schedule = Repo.get!(Schedule, id) |> Repo.preload(:numeric_parameters)
    changeset = Schedule.changeset(schedule)
    render(conn, "edit.html", schedule: schedule, changeset: changeset, form_fields: form_fields())
  end

  def update(conn, %{"id" => id, "schedule" => schedule_params}) do
    schedule = Repo.get!(Schedule, id) |> Repo.preload(:numeric_parameters)
    changeset = Schedule.changeset(schedule, schedule_params)

    case Repo.update(changeset) do
      {:ok, schedule} ->
        conn
        |> put_flash(:info, "Schedule updated successfully.")
        |> redirect(to: schedule_path(conn, :show, schedule))
      {:error, changeset} ->
        render(conn, "edit.html", schedule: schedule, changeset: changeset, form_fields: form_fields())
    end
  end

  def delete(conn, %{"id" => id}) do
    schedule = Repo.get!(Schedule, id) |> Repo.preload(:numeric_parameters)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(schedule)

    conn
    |> put_flash(:info, "Schedule deleted successfully.")
    |> redirect(to: schedule_path(conn, :index))
  end

  defp authorize(conn, _opts) do
    if conn.assigns.authorized do
      conn
    else
      conn
      |> Auth.request_authorization
    end
  end

  defp form_fields do
    numeric_fields = Dynomizer.NumericParameter.numeric_parameter_names
    all_fields = Map.keys(Manager.__struct__)
    manager_fields_map =
      Manager.updatable_fields
      |> Enum.reduce(%{}, fn {manager_name, fields}, m ->
        {numeric, non_numeric} = Enum.split_with(fields, &(Enum.member?(numeric_fields, &1)))
        # "name" and "type" are Manager fields; they have different names in
        # Schedule and need not be in this list of fields.
        non_numeric |> List.delete(:name) |> List.delete(:type)
        Map.put(m, manager_name, %{non_numeric: non_numeric, numeric: numeric})
      end)
    %{non_numeric_fields: all_fields -- numeric_fields,
      numeric_fields: numeric_fields,
      manager_fields_map: manager_fields_map}
  end
end
