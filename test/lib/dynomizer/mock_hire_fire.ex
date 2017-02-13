defmodule Dynomizer.MockHireFire do
  @moduledoc """
  Testing version of HireFire scaler.
  """

  @start_curr_count 10

  use GenServer
  alias Dynomizer.Rule

  # ================ public API ================

  def start_link do
    GenServer.start_link(__MODULE__, {@start_curr_count, []}, name: __MODULE__)
  end

  @doc "Set current dyno count (all apps and dyno types)."
  def set_curr_count(i), do: GenServer.call(__MODULE__, {:set_curr_count, i})

  @doc "Clear all memory of calls to scale."
  def reset, do: GenServer.call(__MODULE__, :reset)

  @doc """
  Return calls to scale as tuples of the form
  `{after_count, schedule}`.
  """
  def scaled, do: GenServer.call(__MODULE__, :scaled)

  def scale(schedule) do
    GenServer.call(__MODULE__, {:scale, schedule})
  end

  # ================ handlers ================

  def handle_call({:set_curr_count, i}, _from, {_, memory}) do
    {:reply, :ok, {i, memory}}
  end

  def handle_call(:reset, _from, {curr_count, _}) do
    {:reply, :ok, {curr_count, []}}
  end

  def handle_call(:scaled, _from, {_, memory} = state) do
    {:reply, Enum.reverse(memory), state}
  end

  def handle_call({:scale, schedule}, _from, {curr_count, memory}) do
    new_count = Rule.apply(schedule.min_rule, schedule.min, schedule.max, curr_count)
    {:reply, new_count, {curr_count, [{new_count, schedule}|memory]}}
  end
end
