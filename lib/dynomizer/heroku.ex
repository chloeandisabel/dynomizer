defmodule Dynomizer.Heroku do
  @moduledoc """
  Responsible for scaling Heroku dynos by modifying Formations.
  """

  @one_day_in_seconds 24 * 60 * 60

  require Logger
  alias Dynomizer.Rule
  alias Dynomizer.HerokuSchedule, as: HS
  alias Happi.Heroku.{App, Formation}

  @doc """
  Applies `schedule` by changing the app's dyno type's min, max, and ratio,
  type, and a few other values.
  """
  def scale(schedule) do
    client = Napper.api_client
    app_id =
      client
      |> App.list
      |> Enum.find(fn app -> app.name == schedule.application end)
      |> Map.get(:id)
    formation =
      client
      |> Formation.list
      |> Enum.find((&(&1.application_id == app_id && &1.name == schedule.dyno_type)))
    updated_fields =
      formation
      |> inspect_log("scaling before")
      |> apply_schedule(schedule)
      |> inspect_log("scaling after")

    client |> Formation.update(formation.id, updated_fields)
  end

  @doc """
  Return the list of application names from HireFire.
  """
  def applications do
    Napper.api_client
    |> App.list
    |> Enum.map(&(&1.name))
    |> Enum.sort
  end

  @doc """
  Return a list of `Dynomizer.HerokuSchedule` structs created from the
  currently defined `Happi.Heroku.Formation` structs associated with
  `application`. The schedule for each is arbitrarily set to one day in the
  past.
  """
  def snapshot(application) do
    client = Napper.api_client
    app = client |> App.list |> Enum.find(&(&1.name == application))
    at =
      %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
      |> NaiveDateTime.add(-@one_day_in_seconds)
      |> NaiveDateTime.to_string
    client
    |> Formation.list
    |> Enum.filter(&(&1.application_id == app.id))
    |> Enum.map(&(schedule_from_formation(&1, application, at)))
  end

  # Given a Heroku Formation struct, return a HerokuSchedule.
  defp schedule_from_formation(formation, application, at) do
    %HS{
      application: application,
      dyno_name: formation.name,
      schedule: at,
      description: "current #{application} #{formation.name}",
      rule: to_string(formation.quantity)
    }
  end

  defp inspect_log(thing, msg) do
    Logger.info("#{msg}: #{inspect thing}")
    thing
  end

  # Modify `formation` by applying new values and rules in `schedule`.
  defp apply_schedule(formation, schedule) do
    new_quantity =
      Rule.apply(schedule.rule, schedule.min, schedule.max, formation.quantity)
    %{formation | quantity: new_quantity}
  end
end
