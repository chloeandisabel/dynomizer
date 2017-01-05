defmodule Dynomizer.Heroku do
  @moduledoc """
  Responsible for scaling Heroku dynos.
  """

  alias Dynomizer.Rule
  alias Happi.Heroku.{Dyno, Formation}

  def scale(app, dyno_type, rule) do
    client = Happi.api_client(app)
    curr_count =
      client
      |> Dyno.list
      |> Enum.filter(fn dyno -> dyno.type == dyno_type end)
      |> length
    new_count = Rule.apply(rule, curr_count)

    formation = client |> Formation.get(dyno_type)
    client |> Formation.update(%{formation | quantity: new_count})
  end
end
