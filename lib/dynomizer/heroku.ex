defmodule Dynomizer.Heroku do
  @moduledoc """
  Responsible for scaling Heroku dynos.
  """

  require Logger
  alias Dynomizer.Rule
  alias Happi.Heroku.{Dyno, Formation}

  @doc """
  Scale `app`'s `dyno_type` using `rule`.
  """
  def scale(app, dyno_type, rule) do
    client = Happi.api_client(app)
    curr_count = curr_count(client, dyno_type)
    new_count = Rule.apply(rule, curr_count)
    formation = client |> Formation.get(dyno_type)
    Logger.info("scaling #{app} #{dyno_type} using #{rule} from #{curr_count} to #{new_count}")
    client |> Formation.update(%{formation | quantity: new_count})
  end

  @doc """
  Return the current number of `dyno_type` dynos of `app`.
  """
  def curr_count(client, dyno_type) do
    client
    |> Dyno.list
    |> Enum.filter(&(&1.type == dyno_type))
    |> length
  end
end
