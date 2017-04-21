defmodule Dynomizer.HerokuScheduleController do
  use Dynomizer.Web, :controller

  alias Dynomizer.HerokuSchedule, as: HS

  def index(conn, _params) do
    schedules = Repo.all(from s in HS, order_by: s.id)
    render(conn, "index.html", schedules: schedules)
  end

  def new(conn, _params) do
    changeset = HS.changeset(%HS{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"schedule" => schedule_params}) do
    changeset = HS.changeset(%HS{}, schedule_params)

    case Repo.insert(changeset) do
      {:ok, _schedule} ->
        conn
        |> put_flash(:info, "HS created successfully.")
        |> redirect(to: heroku_schedule_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    schedule = Repo.get!(HS, id) |> Repo.preload(:numeric_parameters)
    render(conn, "show.html", schedule: schedule)
  end

  def copy(conn, %{"id" => id}) do
    changeset = Repo.get!(HS, id) |> Repo.preload(:numeric_parameters) |> HS.copy_changeset
    render(conn, "new.html", changeset: changeset)
  end

  def edit(conn, %{"id" => id}) do
    schedule = Repo.get!(HS, id) |> Repo.preload(:numeric_parameters)
    changeset = HS.changeset(schedule)
    render(conn, "edit.html", schedule: schedule, changeset: changeset)
  end

  def update(conn, %{"id" => id, "schedule" => schedule_params}) do
    schedule = Repo.get!(HS, id) |> Repo.preload(:numeric_parameters)
    changeset = HS.changeset(schedule, schedule_params)

    case Repo.update(changeset) do
      {:ok, schedule} ->
        conn
        |> put_flash(:info, "Heroku schedule updated successfully.")
        |> redirect(to: heroku_schedule_path(conn, :show, schedule))
      {:error, changeset} ->
        render(conn, "edit.html", schedule: schedule, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    schedule = Repo.get!(HS, id) |> Repo.preload(:numeric_parameters)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(schedule)

    conn
    |> put_flash(:info, "HS deleted successfully.")
    |> redirect(to: heroku_schedule_path(conn, :index))
  end

  def snapshot_form(conn, _params) do
    try do
      {:ok, scaler_module} = Application.fetch_env(:dynomizer, :heroku_scaler)
      applications = scaler_module.applications
      changeset = HS.changeset(%HS{})
      render(conn, "snapshot_form.html", applications: applications, changeset: changeset)
    rescue
      err ->
        conn
        |> put_flash(:info, "Error retrieving application names: #{inspect err}")
        |> redirect(to: heroku_schedule_path(conn, :index))
    end
  end

  def snapshot(conn, %{"schedule" => %{"application" => application}}) do
    try do
      {:ok, scaler_module} = Application.fetch_env(:dynomizer, :scaler)
      scaler_module.snapshot(application)
      |> Enum.map(&(HS.changeset(&1)))
      |> Enum.map(&(Repo.insert!(&1)))

      conn
      |> put_flash(:info, "Snapshot created successfully.")
      |> redirect(to: heroku_schedule_path(conn, :index))
    rescue
      err ->
        conn
        |> put_flash(:info, "Error snapshotting schedules: #{inspect err}")
        |> redirect(to: heroku_schedule_path(conn, :snapshot_form))
    end
  end
end
