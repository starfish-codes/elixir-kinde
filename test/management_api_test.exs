defmodule Kinde.ManagementAPITest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Kinde.TestHelpers
  import Req.Test

  alias Kinde.ManagementAPI

  alias Kinde.TestClients.{
    ClientAuthenticationFailed,
    GetUserError,
    GetUserSuccess,
    InternalServerError,
    ListUsersError,
    ListUsersSuccess,
    RenewTokenSuccess
  }

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
      stub(ManagementAPI, GetUserSuccess)

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      user_id = generate_kinde_id()

      assert {:ok, user} = ManagementAPI.get_user(user_id, pid)

      assert user["id"] == user_id
      assert user["first_name"]
      assert user["last_name"]
      assert user["preferred_email"]
    end

    test "error", %{opts: opts} do
      stub(ManagementAPI, GetUserError)

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      {result, log} = with_log(fn -> ManagementAPI.get_user("does-not-matter", pid) end)

      assert {:error, :kinde_api_error_response} = result
      assert log =~ "Kinde Management API ID_REQUIRED error: ID is required"
      assert log =~ "Kinde Management API USER_INVALID error: User invalid"
    end
  end

  describe "list_users/1" do
    test "success", %{opts: opts} do
      stub(ManagementAPI, ListUsersSuccess)

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      assert {:ok, users} = ManagementAPI.list_users(pid)
      assert Enum.any?(users)
    end

    test "error", %{opts: opts} do
      stub(ManagementAPI, ListUsersError)

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      {result, log} = with_log(fn -> ManagementAPI.list_users(pid) end)

      assert {:error, :kinde_api_unknown_error} = result
      assert log =~ "Unknown Kinde Management API 500 error: \"INTERNAL SERVER ERROR\""
    end
  end

  describe "renew_token" do
    setup %{opts: opts} do
      stub(ManagementAPI, RenewTokenSuccess)

      {:ok, pid} = GenServer.start_link(ManagementAPI, opts)

      %{pid: pid}
    end

    test "success", %{pid: pid} do
      stub(
        ManagementAPI,
        {RenewTokenSuccess, [access_token: "new-access-token", expires_in: 86_399]}
      )

      send(pid, :renew_token)

      Process.sleep(100)

      %{renew_token_timer: timer_ref, access_token: new_token} = :sys.get_state(pid)

      timeout = Process.read_timer(timer_ref)

      assert_in_delta timeout, 86_399_000, 500
      assert new_token == "new-access-token", "Renews access token"
    end

    test "error", %{pid: pid} do
      %{access_token: prev_access_token} = :sys.get_state(pid)

      stub(ManagementAPI, ClientAuthenticationFailed)

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

      stub(ManagementAPI, InternalServerError)

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
  end
end
