defmodule Dynomizer.Auth do
  import Plug.Conn

  @realm System.get_env("BASIC_AUTH_REALM") || "Application"
  @username System.get_env("BASIC_AUTH_USERNAME")
  @password System.get_env("BASIC_AUTH_PASSWORD")

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    authorized = if @username && @password do
      with [auth_header] <- conn |> get_req_header("authorization"),
           ["Basic", word] <- auth_header |> String.split,
           [username, password] <- word |> :base64.decode |> String.split(":")
      do
        username == @username && password == @password
      else
        _ -> false
      end
    else
      true
    end
    assign(conn, :authorized, authorized)
  end

  def request_authorization(conn) do
    conn
    |> put_resp_header("www-authenticate", "Basic realm=#{@realm}")
    |> resp(401, "HTTP Basic: Access denied.\n")
    |> halt()
  end
end
