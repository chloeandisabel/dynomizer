defmodule Dynomizer.MockHireFire do
  @moduledoc """
  Testing version of HireFire scaler.
  """

  @start_min 1
  @start_max 20
  @one_day_in_seconds 24 * 60 * 60

  use GenServer
  alias Dynomizer.Rule
  alias Dynomizer.HirefireSchedule, as: HFS

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

  def applications do
    GenServer.call(__MODULE__, :applications)
  end

  def snapshot(application) do
    GenServer.call(__MODULE__, {:snapshot, application})
  end

  # ================ handlers ================

  def handle_call({:set_curr_min, i}, _from, {_, max, memory}) do
    {:reply, :ok, {i, max, memory}}
  end

  def handle_call({:set_curr_max, i}, _from, {min, _, memory}) do
    {:reply, :ok, {min, i, memory}}
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, {@start_min, @start_max, []}}
  end

  def handle_call(:scaled, _from, {_, _, memory} = state) do
    {:reply, Enum.reverse(memory), state}
  end

  def handle_call({:scale, schedule}, _from, {min, max, memory}) do
    np = Enum.find(schedule.numeric_parameters, fn np -> np.name == "minimum" end)
    new_min = Rule.apply(np.rule, np.min, np.max, min)

    np = Enum.find(schedule.numeric_parameters, fn np -> np.name == "maximum" end)
    new_max = Rule.apply(np.rule, np.min, np.max, max)

    {:reply, {new_min, new_max}, {new_min, new_max, [{new_min, new_max, schedule} | memory]}}
  end

  def handle_call(:applications, _from, state) do
    {:reply, ["app1", "app2"], state}
  end

  def handle_call({:snapshot, app}, _from, state) do
    s1 = app_schedule(app, "web", "ResponseTime")
    s2 = app_schedule(app, "job_worker", "JobQueue")
    {:reply, [s1, s2], state}
  end

  # ================ helpers ================

  defp app_schedule(app, dyno_type, manager_type_suffix) do
    at =
      %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
      |> NaiveDateTime.add(-@one_day_in_seconds)
      |> NaiveDateTime.to_string()

    mgr_type = "Manager::Web::HireFire::#{manager_type_suffix}"

    %HFS{
      application: app,
      description: "current #{app} #{mgr_type}",
      dyno_type: dyno_type,
      manager_type: mgr_type,
      schedule: at,
      enabled: true,
      decrementable: true,
      numeric_parameters: [
        %{name: "minimum", rule: "+5", min: 1, max: 100},
        %{name: "maximum", rule: "+5", min: 1, max: 100},
        %{name: "ratio", rule: "+20", min: 0, max: 100}
      ],
      state: nil
    }
  end
end
