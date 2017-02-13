defmodule Dynomizer.Repo.Migrations.CreateSchedule do
  use Ecto.Migration

  def change do
    create table(:schedules) do
      add :application, :string, size: 32, null: false
      add :dyno_type, :string, size: 32, null: false
      add :manager_type, :string, size: 64, null: false
      add :schedule, :string, null: false
      add :description, :string

      add :decrementable, :boolean
      add :enabled, :boolean
      add :last_checkup_time, :string
      add :last_scale_time, :string
      add :metric_value, :string
      add :new_relic_account_id, :string
      add :new_relic_api_key, :string
      add :new_relic_app_id, :string
      add :notify, :boolean
      add :ratio, :integer
      add :scale_up_on_503, :boolean
      add :url, :string

      add :state, :string, size: 32

      timestamps()
    end
  end
end
