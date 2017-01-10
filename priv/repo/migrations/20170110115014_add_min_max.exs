defmodule Dynomizer.Repo.Migrations.AddMinMax do
  use Ecto.Migration

  def change do
    alter table(:schedules) do
      add :min, :integer
      add :max, :integer
    end
  end
end
