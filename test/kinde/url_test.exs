defmodule Kinde.URLTests do
  use ExUnit.Case
  alias Kinde.URL

  describe "parse/1" do
    test "parses a string into a URI struct" do
      assert %URI{scheme: "https", host: "example.com", path: "/"} =
               URL.parse("https://example.com")
    end

    test "parse a url without scheme into a URI struct" do
      assert %URI{scheme: "https", host: "example.com", path: "/"} = URL.parse("example.com")
    end

    test "parse a url without path into a URI struct" do
      assert %URI{scheme: "https", host: "example.com", path: "/"} =
               URL.parse("https://example.com")
    end

    test "returns the URI struct if it is already a URI struct" do
      uri = %URI{scheme: "https", host: "example.com", path: "/"}
      assert uri == URL.parse(uri)
    end
  end

  describe "parse_to_string/1" do
    test "parses a URI struct into a string" do
      uri = URI.parse("example.com")
      assert "https://example.com/" == URL.parse_to_string(uri)
    end

    test "parses a url without scheme into a full url" do
      assert "https://example.com/" == URL.parse_to_string("example.com")
    end
  end
end
