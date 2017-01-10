defmodule Dynomizer.MockHeroku do
  @moduledoc """
  Testing version of Heroku API.
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
  `{app, dyno_type, rule, before_count, after_count}`.
  """
  def scaled, do: GenServer.call(__MODULE__, :scaled)

  def scale(app, dyno_type, rule, min, max) do
    GenServer.call(__MODULE__, {:scale, app, dyno_type, rule, min, max})
  end

  def curr_count(app, dyno_type) do
    GenServer.call(__MODULE__, {:curr_count, app, dyno_type})
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

  def handle_call({:scale, app, dyno_type, rule, min, max}, _from, {curr_count, memory}) do
    new_count = Rule.apply(rule, min, max, curr_count)
    event = {app, dyno_type, rule, curr_count, new_count}
    {:reply, :ok, {curr_count, [event|memory]}}
  end

  def handle_call({:curr_count, _, _}, _from, {curr_count, _} = state) do
    {:repy, curr_count, state}
  end
end
