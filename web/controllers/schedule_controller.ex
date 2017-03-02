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
    |> IO.inspect(label: "create changeset") # DEBUG

    case Repo.insert(changeset) do
      {:ok, _schedule} ->
        conn
        |> put_flash(:info, "Schedule created successfully.")
        |> redirect(to: schedule_path(conn, :index))
      {:error, changeset} ->
        changeset |> IO.inspect(label: "changeset") # DEBUG
        render(conn, "new.html", changeset: changeset, form_fields: form_fields())
    end
  end

  def show(conn, %{"id" => id}) do
    schedule = Repo.get!(Schedule, id) |> Repo.preload(:numeric_parameters)
    render(conn, "show.html", schedule: schedule, form_fields: form_fields())
  end

  def copy(conn, %{"id" => id}) do
    schedule = Repo.get!(Schedule, id) |> Repo.preload(:numeric_parameters)
    changeset = Schedule.copy_changeset(schedule)
    render(conn, "new.html", changeset: changeset, form_fields: form_fields())
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

  def snapshot_form(conn, _params) do
    try do
      {:ok, scaler_module} = Application.fetch_env(:dynomizer, :scaler)
      applications = scaler_module.applications
      changeset = Schedule.create_changeset(%Schedule{})
      render(conn, "snapshot_form.html", applications: applications,
        changeset: changeset, form_fields: form_fields())
    rescue
      err ->
        conn
        |> put_flash(:info, "Error retrieving application names: #{inspect err}")
        |> redirect(to: schedule_path(conn, :index))
    end
  end

  def snapshot(conn, %{"schedule" => %{"application" => application}}) do
    try do
      {:ok, scaler_module} = Application.fetch_env(:dynomizer, :scaler)
      scaler_module.snapshot(application)
      |> Enum.map(&(Schedule.changeset(&1)))
      |> Enum.map(&(Repo.insert!(&1)))

      conn
      |> put_flash(:info, "Snapshot created successfully.")
      |> redirect(to: schedule_path(conn, :index))
    rescue
      err ->
        conn
        |> put_flash(:info, "Error snapshotting schedules: #{inspect err}")
        |> redirect(to: schedule_path(conn, :snapshot_form))
    end
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
        Map.put(m, manager_name, %{non_numeric: non_numeric -- [:name, :type], numeric: numeric})
      end)
    %{non_numeric_fields: all_fields -- numeric_fields,
      numeric_fields: numeric_fields,
      manager_fields_map: manager_fields_map}
  end
end
