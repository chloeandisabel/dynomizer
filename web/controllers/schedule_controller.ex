defmodule Dynomizer.ScheduleController do
  use Dynomizer.Web, :controller

  alias Dynomizer.Schedule

  def index(conn, _params) do
    schedules = Repo.all(Schedule)
    render(conn, "index.html", schedules: schedules)
  end

  def new(conn, _params) do
    changeset = Schedule.changeset(%Schedule{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"schedule" => schedule_params}) do
    changeset = Schedule.changeset(%Schedule{}, schedule_params)

    case Repo.insert(changeset) do
      {:ok, _schedule} ->
        conn
        |> put_flash(:info, "Schedule created successfully.")
        |> redirect(to: schedule_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    schedule = Repo.get!(Schedule, id)
    render(conn, "show.html", schedule: schedule)
  end

  def edit(conn, %{"id" => id}) do
    schedule = Repo.get!(Schedule, id)
    changeset = Schedule.changeset(schedule)
    render(conn, "edit.html", schedule: schedule, changeset: changeset)
  end

  def update(conn, %{"id" => id, "schedule" => schedule_params}) do
    schedule = Repo.get!(Schedule, id)
    changeset = Schedule.changeset(schedule, schedule_params)

    case Repo.update(changeset) do
      {:ok, schedule} ->
        conn
        |> put_flash(:info, "Schedule updated successfully.")
        |> redirect(to: schedule_path(conn, :show, schedule))
      {:error, changeset} ->
        render(conn, "edit.html", schedule: schedule, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    schedule = Repo.get!(Schedule, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(schedule)

    conn
    |> put_flash(:info, "Schedule deleted successfully.")
    |> redirect(to: schedule_path(conn, :index))
  end
end
