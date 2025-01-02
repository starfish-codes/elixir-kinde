defmodule KindeTest do
  use ExUnit.Case

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias Kinde

  @moduletag :set_req_test_from_context

  @domain "https://mysuperapp.com"

  @config %{
    domain: @domain,
    client_id: "test_client_id",
    client_secret: "test_client_tsecret",
    redirect_uri: "#{@domain}/callback",
    prompt: "create"
  }

  describe "auth/1" do
    test "returns the redirect url for kinde sign in" do
      assert {:ok, redirect_url} = Kinde.auth(@config)

      assert redirect_url =~ "#{@domain}/oauth2/auth?"
    end

    test "sets the default scope if not present" do
      assert {:ok, redirect_url} = Kinde.auth(@config)

      redirect_url = URI.decode(redirect_url)

      [_url, query_params] = String.split(redirect_url, "?")

      assert %{"scope" => "openid profile email offline"} = URI.decode_query(query_params)
    end

    test "sets the custom scope if present" do
      config = Map.put(@config, :scopes, ["openid", "password"])
      assert {:ok, redirect_url} = Kinde.auth(config)

      redirect_url = URI.decode(redirect_url)

      [_url, query_params] = String.split(redirect_url, "?")

      assert %{"scope" => "openid password"} = URI.decode_query(query_params)
    end

    test "returns error if missing config attribute" do
      config = Map.delete(@config, :prompt)

      for {key, _value} <- config do
        invalid_config = Map.delete(config, key)

        assert {:error, :missing_config_key} = Kinde.auth(invalid_config)
      end
    end
  end

  describe "token/3" do
    alias Kinde.StateManagementAgent

    @code Faker.String.base64()
    @kinde_id Faker.UUID.v4()
    @given_name Faker.Person.first_name()
    @family_name Faker.Person.last_name()
    @email Faker.Internet.email()
    @picture Faker.Internet.url()

    setup context do
      state = generate_state()
      extra_params = Map.get(context, :extra_params, %{})

      StateManagementAgent.put_state(state, %{
        code_verifier: generate_verifier(),
        extra_params: extra_params
      })

      %{state: state}
    end

    test "returns token properly", %{state: state} do
      Req.Test.expect(Kinde, fn conn ->
        {:ok, id_token} =
          Kinde.TestJwksStrategy.sign(%{
            "sub" => @kinde_id,
            "given_name" => @given_name,
            "family_name" => @family_name,
            "email" => @email,
            "picture" => @picture
          })

        Req.Test.json(conn, %{"id_token" => id_token})
      end)

      assert {:ok, params, %{}} = Kinde.token(@config, @code, state)

      assert params[:id]
      assert params[:given_name] == @given_name
      assert params[:family_name] == @family_name
      assert params[:email] == @email
      assert params[:picture] == @picture
    end

    @tag extra_params: %{"token-test" => true}
    test "returns extra params properly", %{state: state, extra_params: extra_params} do
      Req.Test.expect(Kinde, fn conn ->
        {:ok, id_token} =
          Kinde.TestJwksStrategy.sign(%{
            "sub" => @kinde_id,
            "given_name" => @given_name,
            "family_name" => @family_name,
            "email" => @email,
            "picture" => @picture
          })

        Req.Test.json(conn, %{"id_token" => id_token})
      end)

      assert {:ok, _params, ^extra_params} = Kinde.token(@config, @code, state)
    end

    test "returns error no_token when request for token fails", %{state: state} do
      Req.Test.expect(Kinde, &Plug.Conn.send_resp(&1, 500, "internal server error"))

      log =
        capture_log(fn ->
          assert {:error, :no_token} = Kinde.token(@config, @code, state)
        end)

      assert log =~ "Couldn't request token: 500"
    end

    test "returns error if missing config attribute", %{state: state} do
      code = Faker.String.base64()
      config = Map.delete(@config, :prompt)

      for {key, _value} <- config do
        invalid_config = Map.delete(config, key)

        assert {:error, :missing_config_key} = Kinde.token(invalid_config, code, state)
      end
    end

    defp generate_state do
      32
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64()
    end

    defp generate_verifier do
      64
      |> :crypto.strong_rand_bytes()
      |> Base.encode16(case: :lower)
    end
  end
end
