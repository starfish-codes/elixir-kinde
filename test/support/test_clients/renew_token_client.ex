defmodule Kinde.TestClients.RenewTokenClient do
  @moduledoc """
  Plug that mocks the behaviour for Authentication call
  """

  @behaviour Plug

  # import Plug.Conn
  import Req.Test

  @test_access_token "test-access-token"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{} = conn, opts) do
    handle_request(conn, opts)
  end

  defp handle_request(%Plug.Conn{request_path: "/oauth2/token"} = conn, opts) do
    response_callback = Keyword.get(opts, :oauth_token)

    if is_function(response_callback),
      do: response_callback.(conn),
      else: oauth2_success(conn)
  end

  defp oauth2_success(%{request_path: "/oauth2/token"} = conn) do
    json(conn, %{
      access_token: @test_access_token,
      expires_in: 86_399,
      scope: "",
      token_type: "bearer"
    })
  end
end
