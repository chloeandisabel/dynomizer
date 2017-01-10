defmodule Dynomizer.Heroku do
  @moduledoc """
  Responsible for scaling Heroku dynos.
  """

  require Logger
  alias Dynomizer.Rule
  alias Happi.Heroku.{Dyno, Formation}

  @doc """
  Scales `schedule`'s app's dyno type and returns the new count.
  """
  def scale(schedule) do
    client = Happi.api_client(schedule.application)
    curr_count = curr_count(client, schedule.dyno_type)
    new_count = Rule.apply(schedule.rule, schedule.min, schedule.max, curr_count)
    formation = client |> Formation.get(schedule.dyno_type)
    Logger.info("scaling #{schedule.application} #{schedule.dyno_type} w/schedule #{schedule.rule} from #{curr_count} to #{new_count}")
    client |> Formation.update(%{formation | quantity: new_count})
    new_count
  end

  @doc """
  Return the current number of `dyno_type` dynos.
  """
  def curr_count(client, dyno_type) do
    client
    |> Dyno.list
    |> Enum.filter(&(&1.type == dyno_type))
    |> length
  end
end
