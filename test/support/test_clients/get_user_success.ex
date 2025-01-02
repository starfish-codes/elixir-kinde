defmodule Kinde.TestClients.GetUserSuccess do
  @moduledoc false

  @behaviour Plug

  import Kinde.TestHelpers
  import Req.Test

  alias Kinde.TestClients.RenewTokenSuccess
  alias Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{request_path: "/oauth2/token"} = conn, opts),
    do: RenewTokenSuccess.call(conn, opts)

  def call(%Conn{request_path: "/api/v1/user", query_params: %{"id" => id}} = conn, _opts),
    do: json(conn, generate_user(id))
end
