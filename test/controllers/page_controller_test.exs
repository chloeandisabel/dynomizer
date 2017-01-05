defmodule Dynomizer.PageControllerTest do
  use Dynomizer.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Dynomizer"
  end
end
