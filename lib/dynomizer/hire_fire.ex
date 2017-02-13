defmodule Dynomizer.HireFire do
  @moduledoc """
  Responsible for scaling Heroku dynos by modifying HireFire rules.
  """

  require Logger
  alias Dynomizer.Rule
  alias Apprentice.HireFire.{Application, Manager}

  @doc """
  Applies `schedule` by changing the app's dyno type's min, max, and ratio,
  type, and a few other values.
  """
  def scale(schedule) do
    client = Napper.api_client
    app_id =
      client
      |> Application.list
      |> Enum.find(fn app -> app.name == schedule.application end)
      |> Map.get(:id)
    manager =
      client
      |> Manager.list
      |> Enum.find(fn mgr -> mgr.application_id == app_id && mgr.name == schedule.dyno_type end)
    Logger.info("scaling before: #{inspect manager}")

    # FIXME if changing type, might not have old value; set of params might
    # be completely different
    manager = %{manager | type: schedule.manager_type}
    manager =
      schedule.numeric_parameters
      |> Enum.reduce(manager, fn (param, map) ->
           key = String.to_atom(param.name)
           current_val = map[key]
           Map.put(map, key, Rule.apply(param.rule, param.min, param.max, current_val))
         end)
      |> Manager.updatable
    Logger.info("scaling after: #{inspect manager}")

    client |> Manager.update(manager)
  end
end
