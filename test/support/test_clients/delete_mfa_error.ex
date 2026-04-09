defmodule Kinde.TestClients.DeleteMfaError do
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

  def call(%Conn{method: "DELETE", request_path: "/api/v1/users/" <> _rest} = conn, _opts) do
    conn
    |> put_status(400)
    |> json(%{
      "errors" => [%{"code" => "MFA_NOT_FOUND", "message" => "MFA not found for user"}]
    })
  end
end
