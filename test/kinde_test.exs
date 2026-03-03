defmodule KindeTest do
  use ExUnit.Case

  import Kinde.TestHelpers
  import Plug.Conn
  import Req.Test

  alias Kinde
  alias Kinde.StateManagementAgent
  alias Kinde.Test.TokenStrategy

  @moduletag :set_req_test_from_context

  setup do
    domain = "https://" <> Faker.Internet.domain_name()

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
      assert {:error, %Kinde.MissingConfigError{} = exception} =
               config
               |> Map.delete(:domain)
               |> Kinde.auth()

      assert "Missing kinde configuration keys: domain" = Exception.message(exception)
    end

    test "can load configuration from the app env", %{config: config, domain: domain} do
      Enum.each(config, fn {name, value} -> Application.put_env(:kinde, name, value) end)

      on_exit(fn ->
        Enum.each(config, fn {name, _value} -> Application.delete_env(:kinde, name) end)
      end)

      assert {:ok, redirect_url} = Kinde.auth()
      assert String.starts_with?(redirect_url, "#{domain}/oauth2/auth?")

      %URI{query: query} = URI.parse(redirect_url)
      assert %{"scope" => "openid profile email offline"} = URI.decode_query(query)
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

      {:ok, id_token} = TokenStrategy.sign(claims)

      code = Faker.String.base64()
      state = Faker.String.base64(44)
      extra_params = Map.get(context, :extra_params, %{})

      StateManagementAgent.put_state(state, %{
        code_verifier: generate_verifier(),
        extra_params: extra_params
      })

      %{
        kinde_id: kinde_id,
        claims: claims,
        id_token: id_token,
        code: code,
        state: state,
        opts: [plug: {Req.Test, Kinde}, retry: false]
      }
    end

    test "returns token properly", %{
      config: config,
      code: code,
      state: state,
      id_token: id_token,
      claims: claims,
      opts: opts
    } do
      expect(Kinde, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"code" => ^code} = URI.decode_query(body)
        json(conn, %{"id_token" => id_token})
      end)

      assert {:ok, params, _extra_params} = Kinde.token(code, state, config, opts)

      assert params[:id] == Map.fetch!(claims, "sub")
      assert params[:given_name] == Map.fetch!(claims, "given_name")
      assert params[:family_name] == Map.fetch!(claims, "family_name")
      assert params[:email] == Map.fetch!(claims, "email")
      assert params[:picture] == Map.fetch!(claims, "picture")
    end

    @tag extra_params: %{"token-test" => true}
    test "returns extra params properly", %{
      config: config,
      opts: opts,
      code: code,
      state: state,
      id_token: id_token,
      extra_params: extra_params
    } do
      expect(Kinde, &json(&1, %{"id_token" => id_token}))

      assert {:ok, _params, ^extra_params} = Kinde.token(code, state, config, opts)
    end

    test "returns error no_token when request for token fails", %{
      opts: opts,
      config: config,
      code: code,
      state: state
    } do
      expect(Kinde, &send_resp(&1, 500, "internal server error"))
      {:error, error} = Kinde.token(code, state, config, opts)
      assert %Kinde.ObtainingTokenError{status: 500} = error
    end

    test "returns error if missing config attribute", %{config: config, code: code, state: state} do
      config = Map.delete(config, :client_id)
      assert {:error, %Kinde.MissingConfigError{} = exception} = Kinde.token(code, state, config)
      assert "Missing kinde configuration keys: client_id" = Exception.message(exception)
    end

    test "returns error if state does not exist", %{
      opts: opts,
      config: config,
      code: code
    } do
      assert {:error, ex} = Kinde.token(code, "does-not-exist", config, opts)
      assert "OIDC state was not found: does-not-exist" = Exception.message(ex)
    end
  end
end
