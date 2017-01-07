defmodule Dynomizer.PageControllerTest do
  use Dynomizer.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert redirected_to(conn) == schedule_path(conn, :index)
  end
end
