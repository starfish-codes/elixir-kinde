defmodule Kinde.TestClients.RenewTokenSuccess do
  @moduledoc """
  Plug that mocks the behaviour for Authentication call
  """

  @behaviour Plug

  import Req.Test

  @default_access_token "test-access-token"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{} = conn, opts) do
    access_token = Keyword.get(opts, :access_token, @default_access_token)
    expires_in = Keyword.get(opts, :expires_in, 86_399)

    json(conn, %{
      access_token: access_token,
      expires_in: expires_in,
      scope: "",
      token_type: "bearer"
    })
  end
end
