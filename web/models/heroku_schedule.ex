defmodule Dynomizer.HerokuSchedule do
  use Dynomizer.Web, :model

  schema "heroku_schedules" do
    field :application, :string, size: 32
    field :dyno_name, :string, size: 32
    field :schedule, :string
    field :description, :string

    field :rule, :string
    field :min, :integer
    field :max, :integer

    field :state, :string, size: 32
    field :method, :string, virtual: true

    timestamps()
  end

  # See Dynomizer.Scheduler.partition.
  def partition_comparator(s1, s2) do
    s1.updated_at == s2.updated_at
  end

  @required_fields [:application, :dyno_name, :schedule, :rule]
  @optional_fields [:min, :max, :state]
  @fields @required_fields ++ @optional_fields

  @doc """
  Builds a changeset for a copy of `struct` (i.e. the same thing with nil id
  fields) based on the `struct` and `params`.
  """
  def copy_changeset(struct) do
    params = %{
      application: struct.application,
      dyno_name: struct.dyno_name,
      schedule: struct.schedule,
      description: struct.description,
      rule: struct.rule,
      min: struct.min,
      max: struct.max
    }
    %__MODULE__{}
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end
end
