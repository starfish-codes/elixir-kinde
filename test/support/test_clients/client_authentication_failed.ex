defmodule Kinde.TestClients.ClientAuthenticationFailed do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn
  import Req.Test

  @error_description "Client authentication failed " <>
                       "(e.g., unknown client, no client authentication included, " <>
                       "or unsupported authentication method)."

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    conn
    |> put_status(401)
    |> json(%{
      error: "invalid_client",
      error_description: @error_description
    })
  end
end
