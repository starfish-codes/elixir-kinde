defmodule Kinde.ManagementAPITest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Kinde.TestHelpers
  import Req.Test

  alias Kinde.ManagementAPI
  alias Kinde.ReqPligins.AllowOwnership

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
  setup %{test: test, stub_with: stub_with} do
    opts = [
      business_domain: Faker.Internet.url(),
      client_id: "KINDE-TEST-CLIENT-ID",
      client_secret: "KINDE-TEST-CLIENT-SECRET",
      req_opts: [
        plug: {Req.Test, ManagementAPI},
        plugins: [AllowOwnership],
        retry: false,
        owner: self()
      ],
      name: Module.concat(__MODULE__, test)
    ]

    stub(ManagementAPI, stub_with)

    %{pid: start_supervised!({ManagementAPI, opts})}
  end

  describe "get_user/2" do
    @tag stub_with: GetUserSuccess
    test "success", %{pid: pid} do
      user_id = generate_kinde_id()

      assert {:ok, user} = ManagementAPI.get_user(user_id, pid)

      assert user["id"] == user_id
      assert user["first_name"]
      assert user["last_name"]
      assert user["preferred_email"]
    end

    @tag stub_with: GetUserError
    test "error", %{pid: pid} do
      assert {:error, %Kinde.APIError{} = ex} = ManagementAPI.get_user("does-not-matter", pid)
      assert Exception.message(ex) =~ "Kinde Management API ID_REQUIRED error: ID is required"
    end

    @tag stub_with: {GetUserError, [errors: ["bad energy"]]}
    test "unexpected error", %{pid: pid} do
      assert {:error, exception} = ManagementAPI.get_user("does-not-matter", pid)

      assert %Kinde.APIError{errors: ["bad energy"]} = exception

      assert Exception.message(exception) ==
               ~S[Kinde Management API unexpected error: "bad energy"]
    end

    @tag stub_with: ClientAuthenticationFailed
    test "no token", %{pid: pid} do
      assert {:error, %Kinde.NoAccessTokenError{} = ex} =
               ManagementAPI.get_user("does-not-matter", pid)

      assert Exception.message(ex) ==
               "Kinde Management API couldn't run the request due to lacking of the access token"
    end
  end

  describe "list_users/1" do
    @tag stub_with: ListUsersSuccess
    test "success", %{pid: pid} do
      assert {:ok, users} = ManagementAPI.list_users(pid)
      assert Enum.any?(users)
    end

    @tag stub_with: {ListUsersSuccess, [total: 0]}
    test "no users", %{pid: pid} do
      assert {:ok, users} = ManagementAPI.list_users(pid)
      assert Enum.empty?(users)
    end

    @tag stub_with: ListUsersError
    test "error", %{pid: pid} do
      {:error, %Kinde.APIError{}} = ManagementAPI.list_users(pid)
    end
  end

  describe "renew_token" do
    @tag stub_with: {RenewTokenSuccess, [access_token: "new-access-token", expires_in: 86_399]}
    test "success", %{pid: pid} do
      send(pid, :renew)

      Process.sleep(100)

      %{renew_token_timer: timer_ref, access_token: new_token} = :sys.get_state(pid)

      timeout = Process.read_timer(timer_ref)

      assert_in_delta timeout, 86_399_000, 500
      assert new_token == "new-access-token", "Renews access token"
    end

    @tag stub_with: ClientAuthenticationFailed
    test "error", %{pid: pid} do
      %{access_token: prev_access_token} = :sys.get_state(pid)

      stub(ManagementAPI, ClientAuthenticationFailed)

      log =
        capture_log(fn ->
          send(pid, :renew)
          Process.sleep(100)
        end)

      %{renew_token_timer: timer_ref, access_token: new_access_token} = :sys.get_state(pid)

      timeout = Process.read_timer(timer_ref)

      assert_in_delta timeout, 300_000, 500, "Schedules next renew in 5 minutes"
      assert new_access_token == prev_access_token, "Doesn't renew access token"
      assert log =~ "Kinde error invalid_client: Client authentication failed"
    end

    @tag stub_with: InternalServerError
    test "unknow error", %{pid: pid} do
      %{access_token: prev_access_token} = :sys.get_state(pid)

      log =
        capture_log(fn ->
          send(pid, :renew)
          Process.sleep(100)
        end)

      %{renew_token_timer: timer_ref, access_token: new_access_token} = :sys.get_state(pid)

      timeout = Process.read_timer(timer_ref)

      assert_in_delta timeout, 300_000, 500, "Schedules next renew in 5 minutes"
      assert new_access_token == prev_access_token, "Doesn't renew access token"
      assert log =~ "Failed to obtain OAuth2 token with the status 500: \"INTERNAL SERVER ERROR\""
    end
  end
end
