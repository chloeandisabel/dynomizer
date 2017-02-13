defmodule Dynomizer.Repo.Migrations.CreateNumericParameter do
  use Ecto.Migration

  def change do
    create table(:numeric_parameters) do
      add :schedule_id, :integer, null: false
      add :name, :string, size: 32, null: false
      add :rule, :string
      add :min, :integer
      add :max, :integer
    end
  end
end
