defmodule Kinde.TestClients.ListUsersError do
  @moduledoc false

  @behaviour Plug

  alias Kinde.TestClients.{InternalServerError, RenewTokenSuccess}
  alias Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{request_path: "/oauth2/token"} = conn, opts),
    do: RenewTokenSuccess.call(conn, opts)

  def call(%Conn{request_path: "/api/v1/users"} = conn, opts),
    do: InternalServerError.call(conn, opts)
end
