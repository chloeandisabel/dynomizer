defmodule Dynomizer.HirefireSchedule do
  use Dynomizer.Web, :model

  alias Dynomizer.NumericParameter

  schema "hirefire_schedules" do
    field :application, :string, size: 32
    field :dyno_type, :string, size: 32
    field :manager_type, :string, size: 64
    field :schedule, :string
    field :description, :string

    field :decrementable, :boolean
    field :enabled, :boolean
    field :last_checkup_time, :string
    field :last_scale_time, :string
    field :metric_value, :string
    field :new_relic_account_id, :string
    field :new_relic_api_key, :string
    field :new_relic_app_id, :string
    field :notify, :boolean
    field :ratio, :integer
    field :scale_up_on_503, :boolean
    field :url, :string

    field :state, :string, size: 32
    field :method, :string, virtual: true

    has_many :numeric_parameters, NumericParameter, on_delete: :delete_all

    timestamps()
  end

  # See Dynomizer.Scheduler.partition.
  def partition_comparator(s1, s2) do
    np_comp = fn(s1_np) ->
      s2_np = Enum.find(s2.numeric_parameters, &(s1_np.name == &1.name))
      s1_np.updated_at == s2_np.updated_at
    end
    s1.updated_at == s2.updated_at && Enum.all?(s1.numeric_parameters, np_comp)
  end

  @required_fields [:application, :dyno_type, :manager_type, :schedule]


  @optional_fields [:description, :decrementable, :enabled,
                    :last_checkup_time, :last_scale_time, :metric_value,
                    :new_relic_account_id, :new_relic_api_key,
                    :new_relic_app_id, :notify, :ratio, :scale_up_on_503,
                    :url, :state]

  @fields @required_fields ++ @optional_fields

  @doc """
  Builds a changeset for a new `struct` with a list of initialized numeric
  params based on the `struct` and `params`.
  """
  def new_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> put_assoc(:numeric_parameters, NumericParameter.changesets_one_of_each)
    |> validate_required(@required_fields)
  end

  @doc """
  Builds a changeset for a copy of `struct` (i.e. the same thing with nil id
  fields) based on the `struct` and `params`.
  """
  def copy_changeset(struct) do
    new_nps = struct.numeric_parameters |> Enum.map((&NumericParameter.copy_changeset(&1)))
    params = %{
      application: struct.application,
      dyno_type: struct.dyno_type,
      manager_type: struct.manager_type,
      schedule: struct.schedule,
      description: struct.description,
      decrementable: struct.decrementable,
      enabled: struct.enabled,
      last_checkup_time: struct.last_checkup_time,
      last_scale_time: struct.last_scale_time,
      metric_value: struct.metric_value,
      new_relic_account_id: struct.new_relic_account_id,
      new_relic_api_key: struct.new_relic_api_key,
      new_relic_app_id: struct.new_relic_app_id,
      notify: struct.notify,
      ratio: struct.ratio,
      scale_up_on_503: struct.scale_up_on_503,
      url: struct.url
    }
    %__MODULE__{}
    |> cast(params, @fields)
    |> put_assoc(:numeric_parameters, new_nps)
    |> validate_required(@required_fields)
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> cast_assoc(:numeric_parameters, required: true)
    |> validate_required(@required_fields)
  end
end
