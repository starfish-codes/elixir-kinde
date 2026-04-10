defmodule Kinde.TestClients.DeleteMfaSuccess do
  @moduledoc false

  @behaviour Plug

  import Req.Test

  alias Kinde.TestClients.RenewTokenSuccess
  alias Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{request_path: "/oauth2/token"} = conn, opts),
    do: RenewTokenSuccess.call(conn, opts)

  def call(%Conn{method: "DELETE", request_path: "/api/v1/users/" <> _rest} = conn, _opts),
    do: json(conn, %{})
end
