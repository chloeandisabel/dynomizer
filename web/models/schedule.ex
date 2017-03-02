defmodule Dynomizer.Schedule do
  use Dynomizer.Web, :model

  alias Dynomizer.NumericParameter

  schema "schedules" do
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

  @doc """
  Given a schedule string return either :cron or :at.

  ## Examples

      iex> alias Dynomizer.Schedule, as: S
      iex> S.method(%S{schedule: "3 5 * * *"})
      :cron
      iex> alias Dynomizer.Schedule, as: S
      iex> S.method(%S{schedule: "2017-01-15 12:34:56"})
      :at
  """
  def method(schedule) do
    if schedule.schedule |> String.trim |> String.split |> length == 5 do
      :cron
    else
      :at
    end
  end

  @doc """
  Given `oldies` and `newbies`, return a tuple of lists `{created, updated,
  deleted, unchanged}`. Used by the `Dynamo.Scheduler` to determine what has
  changed.
  """
  def partition(oldies, newbies) do
    # Create maps from ids to Schedules.
    mapify = fn xs -> xs |> Enum.map(&({&1.id, &1})) |> Enum.into(%{}) end
    old_m = mapify.(oldies)
    new_m = mapify.(newbies)
    old_ids = Map.keys(old_m)
    new_ids = Map.keys(new_m)

    deleted_ids = old_ids -- new_ids
    created_ids = new_ids -- old_ids
    common_ids = MapSet.intersection(MapSet.new(old_ids), MapSet.new(new_ids))
    {unchanged_ids, updated_ids} =
      common_ids
      |> Enum.partition(fn id ->
# FIXME must take into account numeric params
           Map.get(old_m, id).updated_at == Map.get(new_m, id).updated_at
         end)

    take_scheds = fn (m, ids) -> m |> Map.take(ids) |> Map.values end
    {take_scheds.(new_m, created_ids),
     take_scheds.(new_m, updated_ids),
     take_scheds.(old_m, deleted_ids),
     take_scheds.(old_m, unchanged_ids)}
  end

  @doc """
  Returns millisecs since the epoch for an "at" `schedule`. Assumes that the
  schedule string does not contain any time zone offset information at the
  end.
  """
  def to_unix_milliseconds(s) do
    with :at <- method(s),
         {:ok, dt, 0} <- DateTime.from_iso8601(s.schedule <> "Z")
    do
      dt |> DateTime.to_unix(:milliseconds)
    end
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
