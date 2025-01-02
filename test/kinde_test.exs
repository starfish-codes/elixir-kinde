defmodule KindeTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import Kinde.TestHelpers
  import Plug.Conn
  import Req.Test

  alias Kinde
  alias Kinde.StateManagementAgent

  @moduletag :set_req_test_from_context

  setup do
    domain = Faker.Internet.url()

    config = %{
      domain: domain,
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      redirect_uri: Faker.Internet.url(),
      prompt: "create"
    }

    %{domain: domain, config: config}
  end

  describe "auth/1" do
    test "returns the redirect url for kinde sign in", %{domain: domain, config: config} do
      assert {:ok, redirect_url} = Kinde.auth(config)
      assert String.starts_with?(redirect_url, "#{domain}/oauth2/auth?")

      %URI{query: query} = URI.parse(redirect_url)
      assert %{"scope" => "openid profile email offline"} = URI.decode_query(query)
    end

    test "sets the custom scope if present", %{config: config} do
      assert {:ok, redirect_url} =
               config
               |> Map.put(:scopes, ["openid", "password"])
               |> Kinde.auth()

      %URI{query: query} = URI.parse(redirect_url)
      assert %{"scope" => "openid password"} = URI.decode_query(query)
    end

    test "returns error if missing config attribute", %{config: config} do
      assert {:error, :missing_config_key} =
               config
               |> Map.delete(:domain)
               |> Kinde.auth()
    end
  end

  describe "token/3" do
    setup context do
      kinde_id = generate_kinde_id()

      claims = %{
        "sub" => kinde_id,
        "given_name" => Faker.Person.first_name(),
        "family_name" => Faker.Person.last_name(),
        "email" => Faker.Internet.email(),
        "picture" => Faker.Internet.url()
      }

      {:ok, id_token} = Kinde.TestJwksStrategy.sign(claims)

      code = Faker.String.base64()
      state = Faker.String.base64(44)
      extra_params = Map.get(context, :extra_params, %{})

      StateManagementAgent.put_state(state, %{
        code_verifier: generate_verifier(),
        extra_params: extra_params
      })

      %{kinde_id: kinde_id, claims: claims, id_token: id_token, code: code, state: state}
    end

    test "returns token properly", %{
      config: config,
      code: code,
      state: state,
      id_token: id_token,
      claims: claims
    } do
      expect(Kinde, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"code" => ^code} = URI.decode_query(body)
        json(conn, %{"id_token" => id_token})
      end)

      assert {:ok, params, _extra_params} = Kinde.token(config, code, state)

      assert params[:id] == Map.fetch!(claims, "sub")
      assert params[:given_name] == Map.fetch!(claims, "given_name")
      assert params[:family_name] == Map.fetch!(claims, "family_name")
      assert params[:email] == Map.fetch!(claims, "email")
      assert params[:picture] == Map.fetch!(claims, "picture")
    end

    @tag extra_params: %{"token-test" => true}
    test "returns extra params properly", %{
      config: config,
      code: code,
      state: state,
      id_token: id_token,
      extra_params: extra_params
    } do
      expect(Kinde, &json(&1, %{"id_token" => id_token}))

      assert {:ok, _params, ^extra_params} = Kinde.token(config, code, state)
    end

    test "returns error no_token when request for token fails", %{
      config: config,
      code: code,
      state: state
    } do
      expect(Kinde, &send_resp(&1, 500, "internal server error"))
      {result, log} = with_log(fn -> Kinde.token(config, code, state) end)
      assert {:error, :no_token} = result
      assert log =~ "Couldn't request token: 500"
    end

    test "returns error if missing config attribute", %{config: config, code: code, state: state} do
      assert {:error, :missing_config_key} =
               config
               |> Map.delete(:client_id)
               |> Kinde.token(code, state)
    end
  end
end
