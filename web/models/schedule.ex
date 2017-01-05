defmodule Dynomizer.Schedule do
  use Dynomizer.Web, :model

  schema "schedules" do
    field :application, :string, size: 32
    field :dyno_type, :string, size: 32
    field :rule, :string
    field :schedule, :string
    field :schedule_method, :string, size: 8
    field :description, :string
    field :state, :string, size: 32

    timestamps()
  end

  @required_fields [:application, :dyno_type, :rule, :schedule, :schedule_method]
  @optional_fields [:description, :state]
  @fields @required_fields ++ @optional_fields
  @methods ~w(cron at)

  @doc """
  Translate a schedule string, assumed to be for an :at schedule, to a
  datetime.
  """
  def naive_datetime(at_str) do
    with {:ok, dt} <- NaiveDateTime.from_iso8601(at_str) do
      dt
    else
      err -> err
    end
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end


  @doc """
  Builds a changeset based on the `struct` and `params`, setting the proper
  `schedule _method` based on the format of `schedule`.
  """
  def schedule_changeset(struct, params \\ %{}) do
    key = if (params == %{} || (params |> Map.keys |> hd |> is_atom)) do
      :schedule_method
    else
      "schedule_method"
    end
    params_with_method =
      params
      |> Map.put(key, method(params[:schedule] || params["schedule"]))
    changeset(struct, params_with_method)
  end

  # Given a schedule string return either "cron" or "at".
  defp method(nil), do: nil
  defp method(schedule) do
    if schedule |> String.trim |> String.split |> length == 5 do
      "cron"
    else
      "at"
    end
  end
end
