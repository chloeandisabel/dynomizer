defmodule Dynomizer.Schedule do
  use Dynomizer.Web, :model

  schema "schedules" do
    field :application, :string, size: 32
    field :dyno_type, :string, size: 32
    field :rule, :string
    field :min, :integer
    field :max, :integer
    field :schedule, :string
    field :description, :string
    field :state, :string, size: 32
    field :method, :string, virtual: true

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

  @required_fields [:application, :dyno_type, :rule, :schedule]
  @optional_fields [:description, :state]
  @fields @required_fields ++ @optional_fields

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end
end
