defmodule Dynomizer.Heroku do
  @moduledoc """
  Responsible for scaling Heroku dynos.
  """

  alias Dynomizer.Rule
  alias Happi.Heroku.{Dyno, Formation}

  @doc """
  Scale `app`'s `dyno_type` using `rule`.
  """
  def scale(app, dyno_type, rule) do
    client = Happi.api_client(app)
    new_count = Rule.apply(rule, curr_count(client, dyno_type))
    formation = client |> Formation.get(dyno_type)
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
