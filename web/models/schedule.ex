defmodule Dynomizer.Schedule do
  use Dynomizer.Web, :model

  schema "schedules" do
    field :application, :string, size: 32
    field :dyno_type, :string, size: 32
    field :rule, :string
    field :schedule, :string
    field :description, :string
    field :state, :string, size: 32

    timestamps()
  end

  # Given a schedule string return either :cron or :at.
  def method(schedule) do
    if schedule.schedule |> String.trim |> String.split |> length == 5 do
      :cron
    else
      :at
    end
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
