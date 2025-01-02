defmodule Kinde.ManagementAPITest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog, only: [capture_log: 1, with_log: 1]

  alias Kinde.ManagementAPI
  alias Kinde.TestClients.{GetUserClient, ListUsersClient, RenewTokenClient}

  @moduletag :capture_log
  setup do
    %{
      opts: [
        business_domain: Faker.Internet.url(),
        client_id: "KINDE-TEST-CLIENT-ID",
        client_secret: "KINDE-TEST-CLIENT-SECRET",
        owner: self()
      ]
    }
  end

  describe "get_user/2" do
    test "success", %{opts: opts} do
      Req.Test.stub(ManagementAPI, GetUserClient)

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      user_id = "kp_9657302f36e640a5bad5dbf3aa548e04"

      assert {:ok, user} = ManagementAPI.get_user(user_id, pid)

      assert user["id"] == user_id
      assert user["first_name"] == "John"
      assert user["last_name"] == "Doe"
      assert user["preferred_email"] == "john.doe@email.team"
    end

    test "error", %{opts: opts} do
      Req.Test.stub(ManagementAPI, {GetUserClient, get_user: &get_user_error_mock/1})

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      {result, log} = with_log(fn -> ManagementAPI.get_user("does-not-matter", pid) end)

      assert {:error, :kinde_api_error_response} = result
      assert log =~ "Kinde Management API ID_REQUIRED error: ID is required"
      assert log =~ "Kinde Management API USER_INVALID error: User invalid"
    end

    defp get_user_error_mock(%{request_path: "/api/v1/user"} = conn) do
      error = %{
        "errors" => [
          %{"code" => "ID_REQUIRED", "message" => "ID is required"},
          %{"code" => "USER_INVALID", "message" => "User invalid"}
        ]
      }

      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(error)
    end
  end

  describe "list_users/1" do
    test "success", %{opts: opts} do
      Req.Test.stub(ManagementAPI, ListUsersClient)

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      assert {:ok, users} = ManagementAPI.list_users(pid)
      assert Enum.any?(users)
    end

    test "error", %{opts: opts} do
      Req.Test.stub(ManagementAPI, {ListUsersClient, list_users: &list_users_error_mock/1})

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      {result, log} = with_log(fn -> ManagementAPI.list_users(pid) end)

      assert {:error, :kinde_api_unknown_error} = result
      assert log =~ "Unknown Kinde Management API 500 error: \"INTERNAL SERVER ERROR\""
    end

    defp list_users_error_mock(%{request_path: "/api/v1/users"} = conn) do
      Plug.Conn.send_resp(conn, 500, "INTERNAL SERVER ERROR")
    end
  end

  describe "renew_token" do
    setup %{opts: opts} do
      Req.Test.stub(ManagementAPI, RenewTokenClient)

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      %{pid: pid}
    end

    test "success", %{pid: pid} do
      Req.Test.stub(ManagementAPI, {RenewTokenClient, oauth_token: &renew_token_mock/1})

      send(pid, :renew_token)

      Process.sleep(100)

      %{renew_token_timer: timer_ref, access_token: new_token} = :sys.get_state(pid)

      timeout = Process.read_timer(timer_ref)

      assert_in_delta timeout, 86_399_000, 500
      assert new_token == "new-access-token", "Renews access token"
    end

    test "error", %{pid: pid} do
      %{access_token: prev_access_token} = :sys.get_state(pid)

      Req.Test.stub(ManagementAPI, {RenewTokenClient, oauth_token: &renew_token_error_mock/1})

      log =
        capture_log(fn ->
          send(pid, :renew_token)
          Process.sleep(100)
        end)

      %{renew_token_timer: timer_ref, access_token: new_access_token} = :sys.get_state(pid)

      timeout = Process.read_timer(timer_ref)

      assert_in_delta timeout, 300_000, 500, "Schedules next renew in 5 minutes"
      assert new_access_token == prev_access_token, "Doesn't renew access token"
      assert log =~ "Kinde error: Client authentication failed"
    end

    test "unknow error", %{pid: pid} do
      %{access_token: prev_access_token} = :sys.get_state(pid)

      Req.Test.stub(
        ManagementAPI,
        {RenewTokenClient, oauth_token: &Plug.Conn.send_resp(&1, 500, "INTERNAL SERVER ERROR")}
      )

      log =
        capture_log(fn ->
          send(pid, :renew_token)
          Process.sleep(100)
        end)

      %{renew_token_timer: timer_ref, access_token: new_access_token} = :sys.get_state(pid)

      timeout = Process.read_timer(timer_ref)

      assert_in_delta timeout, 300_000, 500, "Schedules next renew in 5 minutes"
      assert new_access_token == prev_access_token, "Doesn't renew access token"
      assert log =~ "Unknown Kinde 500 error: \"INTERNAL SERVER ERROR\""
    end

    defp renew_token_mock(conn) do
      Req.Test.json(conn, %{
        access_token: "new-access-token",
        expires_in: 86_399,
        scope: "",
        token_type: "bearer"
      })
    end

    defp renew_token_error_mock(conn) do
      conn
      |> Plug.Conn.put_status(401)
      |> Req.Test.json(%{
        error: "invalid_client",
        error_description:
          "Client authentication failed (e.g., unknown client, no client authentication included, or unsupported authentication method)."
      })
    end
  end
end
