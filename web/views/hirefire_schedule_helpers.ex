defmodule Dynomizer.HirefireScheduleHelpers do
  @moduledoc """
  Conveniences for displaying schedules.
  """

  use Phoenix.HTML

  @doc """
  Slightly more readable HireFire manager type.
  """
  def manager_type_display(str) do
    str |> String.split("::") |> tl |> Enum.join(" ")
  end

  @doc """
  Manager type select options.
  """
  def manager_type_select_options(types) do
    types
    |> Enum.map(&({manager_type_display(&1), &1}))
    |> Enum.into(%{})
  end

end
