defmodule Dynomizer.Heroku do
  @moduledoc """
  Responsible for scaling Heroku dynos.
  """

  require Logger
  alias Dynomizer.Rule
  alias Happi.Heroku.Formation

  @doc """
  Scales `schedule`'s app's dyno type and returns the new count.
  """
  def scale(schedule) do
    client = Napper.api_client(app: schedule.application)
    formation = client |> Formation.get(schedule.dyno_type)
    curr_count = formation.quantity
    new_count = Rule.apply(schedule.rule, schedule.min, schedule.max, curr_count)
    Logger.info("scaling #{schedule.application} #{schedule.dyno_type} using #{schedule.rule} from #{curr_count} to #{new_count}")
    client |> Formation.update(%{updates: [%{type: schedule.dyno_type,
                                             quantity: new_count}]})
    new_count
  end
end
