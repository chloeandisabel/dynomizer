defmodule Dynomizer.LayoutView do
  use Dynomizer.Web, :view

  def js_view_name(conn, view_template) do
    [view_name(conn), template_name(view_template)]
    |> Enum.reverse
    |> List.insert_at(0, "view")
    |> Enum.map(&String.capitalize/1)
    |> Enum.reverse
    |> Enum.join("")
  end

  defp view_name(conn) do
    conn
    |> view_module
    |> Phoenix.Naming.resource_name
    |> String.replace("_view", "")
  end

  defp template_name(view_template) when is_binary(view_template) do
    view_template
    |> String.split(".")
    |> Enum.at(0)
  end
end
