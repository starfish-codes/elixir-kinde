defmodule Kinde.URLTest do
  use ExUnit.Case
  alias Kinde.URL

  describe "auth_url/2" do
    test "can handle domain both with and without scheme" do
      assert "https://example.com/oauth2/auth?x=1" = URL.auth_url("https://example.com", "x=1")
      assert "https://example.com/oauth2/auth?x=1" = URL.auth_url("example.com", "x=1")
    end
  end

  describe "jwks_url/1" do
    test "can handle domain both with and without scheme" do
      assert "https://example.com/.well-known/jwks" = URL.jwks_url("https://example.com")
      assert "https://example.com/.well-known/jwks" = URL.jwks_url("example.com")
    end
  end
end
