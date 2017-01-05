defmodule Dynomizer.Repo.Migrations.CreateSchedule do
  use Ecto.Migration

  def change do
    create table(:schedules) do
      add :application, :string, size: 32
      add :dyno_type, :string, size: 32
      add :rule, :string
      add :schedule, :string
      add :schedule_method, :string, size: 8
      add :description, :string
      add :state, :string, size: 32

      timestamps()
    end

  end
end
