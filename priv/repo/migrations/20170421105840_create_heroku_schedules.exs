defmodule Dynomizer.Repo.Migrations.CreateHerokuSchedules do
  use Ecto.Migration

  def change do
    rename table(:schedules), to: table(:hirefire_schedules)
    rename table(:numeric_parameters), :schedule_id, to: :hirefire_schedule_id

    create table(:heroku_schedules) do
      add :application, :string, size: 32, null: false
      add :dyno_name, :string, size: 32, null: false
      add :schedule, :string, null: false
      add :description, :string

      add :rule, :string
      add :min, :integer
      add :max, :integer

      add :state, :string, size: 32

      timestamps()
    end
  end
end
