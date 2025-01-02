defmodule Kinde.TestClients.GetUserError do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn
  import Req.Test

  alias Kinde.TestClients.RenewTokenSuccess
  alias Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{request_path: "/oauth2/token"} = conn, opts),
    do: RenewTokenSuccess.call(conn, opts)

  def call(%Conn{request_path: "/api/v1/user"} = conn, _opts) do
    conn
    |> put_status(400)
    |> json(%{
      "errors" => [
        %{"code" => "ID_REQUIRED", "message" => "ID is required"},
        %{"code" => "USER_INVALID", "message" => "User invalid"}
      ]
    })
  end
end
