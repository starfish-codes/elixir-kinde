defmodule Kinde.TestClients.ManagementAPI do
  @moduledoc """
  Plug that mocks the behaviour for Authentication call
  """

  @behaviour Plug

  import Plug.Conn
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

  defp handle_request(%Plug.Conn{request_path: "/api/v1/user"} = conn, opts) do
    response_callback = Keyword.get(opts, :get_user)

    if is_function(response_callback),
      do: response_callback.(conn),
      else: user_success(conn)
  end

  defp user_success(%{request_path: "/api/v1/user", query_params: %{"id" => kinde_id}} = conn) do
    json(conn, %{
      "id" => kinde_id,
      "first_name" => "John",
      "last_name" => "Doe",
      "preferred_email" => "john.doe@starfish.team",
      "provided_id" => "82cef2c2-31c2-4b95-b0f8-a169bc4c27a5",
      "is_suspended" => false,
      "total_sign_ins" => 0,
      "failed_sign_ins" => 0,
      "created_on" => "2024-03-28T11:37:16.262151+00:00"
    })
  end
end
