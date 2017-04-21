defmodule Dynomizer.Auth do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    authed = authorized?(conn)
    assign(conn, :authorized, authed)
    if authed do
      conn
    else
      request_authorization(conn)
    end
  end

  def request_authorization(conn) do
    realm = System.get_env("BASIC_AUTH_REALM") || "Application"
    conn
    |> put_resp_header("www-authenticate", "Basic realm=#{realm}")
    |> resp(401, "HTTP Basic: Access denied.\n")
    |> halt()
  end

  defp authorized?(conn) do
    username = System.get_env("BASIC_AUTH_USERNAME")
    password = System.get_env("BASIC_AUTH_PASSWORD")

    if username || password do
      with [auth_header] <- conn |> get_req_header("authorization"),
           ["Basic", word] <- auth_header |> String.split,
           [u, p] <- word |> :base64.decode |> String.split(":")
        do
          (username || "") == u && (password || "") == p
        else
          _ -> false
      end
    else
      true
    end
  end
end
