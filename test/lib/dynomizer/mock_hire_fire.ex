defmodule Dynomizer.MockHireFire do
  @moduledoc """
  Testing version of HireFire scaler.
  """

  @start_min 1
  @start_max 20

  use GenServer
  alias Dynomizer.Rule

  # ================ public API ================

  def start_link do
    GenServer.start_link(__MODULE__, {@start_min, @start_max, []}, name: __MODULE__)
  end

  @doc "Set current dyno min (all apps and dyno types)."
  def set_curr_min(i), do: GenServer.call(__MODULE__, {:set_curr_min, i})

  @doc "Set current dyno max (all apps and dyno types)."
  def set_curr_max(i), do: GenServer.call(__MODULE__, {:set_curr_max, i})

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

  def handle_call({:set_curr_min, i}, _from, {_, max, memory}) do
    {:reply, :ok, {i, max, memory}}
  end

  def handle_call({:set_curr_max, i}, _from, {min, _, memory}) do
    {:reply, :ok, {min, i, memory}}
  end

  def handle_call(:reset, _from, {min, max, _}) do
    {:reply, :ok, {min, max, []}}
  end

  def handle_call(:scaled, _from, {_, _, memory} = state) do
    {:reply, Enum.reverse(memory), state}
  end

  def handle_call({:scale, schedule}, _from, {min, max, memory}) do
    np = Enum.find(schedule.numeric_parameters, fn np -> np.name == "minimum" end)
    new_min = Rule.apply(np.rule, np.min, np.max, min)

    np = Enum.find(schedule.numeric_parameters, fn np -> np.name == "maximum" end)
    new_max = Rule.apply(np.rule, np.min, np.max, max)

    {:reply, {new_min, new_max}, {new_min, new_max, [{new_min, new_max, schedule}|memory]}}
  end
end
