defmodule Dynomizer.PageController do
  use Dynomizer.Web, :controller

  def index(conn, _params) do
    redirect conn, to: schedule_path(conn, :index)
  end
end
