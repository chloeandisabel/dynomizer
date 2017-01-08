ExUnit.start

Ecto.Adapters.SQL.Sandbox.mode(Dynomizer.Repo, :manual)

# The test task does not load non-test files in the test directory, so
# here's some mock code used by some tests. If this gets any bigger or there
# are more mocks to define, you can move them into files in the test dir
# somwhere then call `Code.require_file("test/foo/my_mock.ex")`.

defmodule Dynomizer.MockHeroku do
  @moduledoc """
  Testing version of Heroku API.
  """

  alias Dynomizer.Rule

  @doc "Clear all memory of calls to scale."
  def reset do
    Process.delete(__MODULE__)
  end

  def scaled do
    Process.get(__MODULE__, []) |> Enum.reverse
  end

  def scale(app, dyno_type, rule) do
    curr_count = curr_count(app, dyno_type)
    new_count = Rule.apply(rule, curr_count)
    remember(app, dyno_type, rule, curr_count, new_count)
  end

  def curr_count(_, _), do: 10

  defp remember(app, dyno_type, rule, curr_count, new_count) do
    entries = Process.get(__MODULE__, [])
    entry = {app, dyno_type, rule, curr_count, new_count}
    Process.put(__MODULE__, [entry|entries])
  end
end
