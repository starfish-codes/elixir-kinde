defmodule KindeTest do
  use ExUnit.Case, async: true

  alias Kinde

  @domain "https://mysuperapp.com"

  describe "auth/1" do
    @config %{
      domain: @domain,
      client_id: "test_client_id",
      client_secret: "test_client_tsecret",
      redirect_uri: "#{@domain}/callback",
      prompt: "create"
    }

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
  end
end
