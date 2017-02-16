defmodule Dynomizer.HireFire do
  @moduledoc """
  Responsible for scaling Heroku dynos by modifying HireFire rules.
  """

  @ignore_fields [
    :application, :dyno_type, :schedule, :description, :state, :method,
    :inserted_at, :updated_at
  ]
  @inapplicable_error "can not apply relative change without an initial value"

  require Logger
  alias Dynomizer.{Rule, Schedule}
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
      |> Enum.find((&(&1.application_id == app_id && &1.name == schedule.dyno_type)))
      |> inspect_log("scaling before")
      |> apply_schedule(schedule)
      |> inspect_log("scaling after")

    client |> Manager.update(manager)
  end

  defp inspect_log(thing, msg) do
    Logger.info("#{msg}: #{inspect thing}")
    thing
  end

  # Modify `manager` by applying new values and rules in `schedule`.
  #
  # Normally the manager type will not change. If it does, we might not have
  # an original value to modify for one or more numeric parameters. In that
  # case, the rule for that numeric parameter MUST be an absolute number, not
  # a modifier (+/-, %, etc.). If we have a modifier then log an error and
  # return the manager unmodified.
  defp apply_schedule(manager, schedule) do
    case inapplicable_params(manager, schedule) do
      [] ->
        new_numeric_vals =
          schedule.numeric_parameters
          |> Enum.map(fn np ->
               key = String.to_atom(np.name)
               current_val = manager[key]
               {key, Rule.apply(np.rule, np.min, np.max, current_val)}
             end)
        |> Enum.into(%{})

        %{manager | type: schedule.manager_type}
        |> Map.merge(Map.drop(schedule, @ignore_fields))
        |> Map.merge(new_numeric_vals)
        |> Manager.updatable
      errors ->
        Enum.map(errors, fn {name, msg} ->
          Logger.error("schedule #{schedule.id} #{name}: #{msg}")
        end)
        manager
    end
  end

  defp inapplicable_params(%Manager{type: t}, %Schedule{manager_type: t}), do: []
  defp inapplicable_params(manager, schedule) do
    schedule.numeric_parameters
    |> Enum.filter(fn np ->
      key = String.to_atom(np.name)
      manager[key] == nil && !Rule.absolute?(np.rule)
    end)
    |> Enum.map(&({&1.name, @inapplicable_error}))
  end
end
