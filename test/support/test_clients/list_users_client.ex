defmodule Kinde.TestClients.ListUsersClient do
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

  defp handle_request(%Plug.Conn{request_path: "/oauth2/token"} = conn, _opts) do
    json(conn, %{
      access_token: @test_access_token,
      expires_in: 86_399,
      scope: "",
      token_type: "bearer"
    })
  end

  defp handle_request(%Plug.Conn{request_path: "/api/v1/users"} = conn, opts) do
    response_callback = Keyword.get(opts, :list_users)

    if is_function(response_callback),
      do: response_callback.(conn),
      else: users_success(conn)
  end

  defp users_success(
         %{request_path: "/api/v1/users", query_params: %{"next_token" => _next_token}} = conn
       ) do
    Req.Test.json(conn, %{
      code: "OK",
      message: "Success",
      users: nil,
      next_token: nil
    })
  end

  defp users_success(%{request_path: "/api/v1/users", query_params: %{}} = conn) do
    json(conn, %{
      code: "OK",
      message: "Success",
      users: [
        %{name: "Dude 1"},
        %{name: "Dude 2"}
      ],
      next_token: "Mjc6OjpuYW1lX2FzYw=="
    })
  end
end
