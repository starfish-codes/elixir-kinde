defmodule Kinde.ManagementAPITest do
  use ExUnit.Case

  import ExUnit.CaptureLog, only: [capture_log: 1, with_log: 1]

  alias Kinde.ManagementAPI
  alias Kinde.TestClients.ManagementAPI, as: TestClient

  @moduletag :capture_log

  @test_access_token "test-access-token"

  @params [
    business_domain: "https://starfish.kinde.com",
    client_id: "KINDE-TEST-CLIENT-ID",
    client_secret: "KINDE-TEST-CLIENT-SECRET"
  ]

  #  setup do
  #    Req.Test.expect(Kinde.ManagementAPI, &mock_oauth2_token/1)
  #
  #    IO.inspect(self(), label: :outside)
  #
  #    params =
  #      Keyword.put(@params, :prepend_request,
  #        allow: fn request ->
  #          IO.inspect(self(), label: :inside)
  #          IO.inspect(Process.whereis(ManagementAPI), label: :management)
  #          # pid = Process.whereis(ManagementAPI)
  #
  #          # Req.Test.allow(ManagementAPI, self(), pid) |> dbg()
  #          request
  #        end
  #      )
  #
  #    {:ok, pid} = GenServer.start(ManagementAPI, params, name: ManagementAPI)
  #
  #    # Req.Test.allow(ManagementAPI, self(), pid)
  #
  #    on_exit(fn -> GenServer.stop(pid) end)
  #
  #    :ok
  #  end

  describe "get_user/1" do
    test "success" do
      user_id = "kp_9657302f36e640a5bad5dbf3aa548e04"

      Req.Test.stub(ManagementAPI, TestClient)

      pid = start_supervised!({ManagementAPI, @params})

      dbg(pid)
      dbg(self())
      Req.Test.allow(ManagementAPI, self(), pid)

      assert {:ok, user} = ManagementAPI.get_user(user_id)

      assert user["id"] == user_id
      assert user["first_name"] == "John"
      assert user["last_name"] == "Doe"
      assert user["preferred_email"] == "john.doe@starfish.team"
    end

    test "error" do
      # Req.Test.expect(Kinde.ManagementAPI, &get_user_error_mock/1)
      Req.Test.stub(ManagementAPI, {TestClient, get_user: &get_user_error_mock/1})

      pid = start_supervised!({ManagementAPI, @params})

      Req.Test.allow(ManagementAPI, self(), pid)

      {result, log} = with_log(fn -> ManagementAPI.get_user("does-not-matter") end)
      assert {:error, :kinde_api_error_response} = result
      assert log =~ "Kinde Management API ID_REQUIRED error: ID is required"
      assert log =~ "Kinde Management API USER_INVALID error: User invalid"
    end

    defp get_user_error_mock(%{request_path: "/api/v1/user"} = conn) do
      error = %{
        "errors" => [
          %{
            code: "ID_REQUIRED",
            message: "ID is required"
          },
          %{
            "code" => "USER_INVALID",
            "message" => "User invalid"
          }
        ]
      }

      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(error)
    end
  end

  describe "list_users/0" do
    test "success" do
      Req.Test.expect(Kinde.ManagementAPI, 2, &list_users_mock/1)
      assert {:ok, users} = ManagementAPI.list_users()
      assert Enum.any?(users)
    end

    test "error" do
      Req.Test.expect(Kinde.ManagementAPI, 4, &list_users_error_mock/1)

      {result, log} = with_log(fn -> ManagementAPI.list_users() end)
      assert {:error, :kinde_api_unknown_error} = result
      assert log =~ "Unknown Kinde Management API 500 error: \"INTERNAL SERVER ERROR\""
    end

    defp list_users_mock(
           %{request_path: "/api/v1/users", query_params: %{"next_token" => _next_token}} = conn
         ) do
      Req.Test.json(conn, %{
        code: "OK",
        message: "Success",
        users: nil,
        next_token: nil
      })
    end

    defp list_users_mock(%{request_path: "/api/v1/users"} = conn) do
      Req.Test.json(conn, %{
        code: "OK",
        message: "Success",
        users: [
          %{name: "Dude 1"},
          %{name: "Dude 2"}
        ],
        next_token: "Mjc6OjpuYW1lX2FzYw=="
      })
    end

    defp list_users_error_mock(%{request_path: "/api/v1/users"} = conn) do
      Plug.Conn.send_resp(conn, 500, "INTERNAL SERVER ERROR")
    end
  end

  describe "renew_token" do
    test "error" do
      pid = Process.whereis(ManagementAPI)
      %{access_token: prev_access_token} = :sys.get_state(pid)

      Req.Test.expect(Kinde.ManagementAPI, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{
          error: "invalid_client",
          error_description:
            "Client authentication failed (e.g., unknown client, no client authentication included, or unsupported authentication method)."
        })
      end)

      log =
        capture_log(fn ->
          send(pid, :renew_token)
          Process.sleep(100)
        end)

      pid = Process.whereis(ManagementAPI)

      %{renew_token_timer: timer_ref, access_token: new_access_token} = :sys.get_state(pid)
      timeout = Process.read_timer(timer_ref)
      assert_in_delta timeout, 300_000, 500, "Schedules next renew in 5 minutes"
      assert new_access_token == prev_access_token, "Doesn't renew access token"
      assert log =~ "Kinde error: Client authentication failed"
    end
  end

  defp mock_oauth2_token(%{request_path: "/oauth2/token"} = conn) do
    dbg()

    Req.Test.json(conn, %{
      access_token: @test_access_token,
      expires_in: 86_399,
      scope: "",
      token_type: "bearer"
    })
  end
end
