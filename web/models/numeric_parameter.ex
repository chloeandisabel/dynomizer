defmodule Dynomizer.NumericParameter do
  use Dynomizer.Web, :model

  alias Dynomizer.HirefireSchedule, as: HFS

  schema "numeric_parameters" do
    field :name, :string, size: 32
    field :rule, :string, size: 16
    field :min, :integer
    field :max, :integer

    belongs_to :hirefire_schedule, HFS

    timestamps()
  end
  
  @fields [:name, :rule, :min, :max]
  @required_fields [:name]
  @numeric_parameter_names [
    :minimum, :maximum, :notify_quantity, :notify_after, :upscale_quantity,
    :upscale_sensitivity, :upscale_timeout, :downscale_quantity,
    :downscale_sensitivity, :downscale_timeout, :dyno_quantity,
    :maximum_apdex, :maximum_load, :maximum_response_time, :minimum_apdex,
    :minimum_load, :minimum_response_time, :ratio
  ]

  def numeric_parameter_names, do: @numeric_parameter_names

  def changesets_one_of_each do
    @numeric_parameter_names
    |> Enum.map(&(changeset(%__MODULE__{}, %{name: to_string(&1)})))
  end

  @doc """
  Builds a changeset for a copy of `struct` (i.e. the same thing with nil id
  fields) based on the `struct` and `params`.
  """
  def copy_changeset(struct) do
    changeset(%__MODULE__{}, Map.take(struct, [:name, :rule, :min, :max]))
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
