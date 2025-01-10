defmodule Kinde.URL do
  @moduledoc """
  Provides URL helpers
  """

  @spec base_url(String.t()) :: String.t()
  def base_url(domain) do
    domain
    |> parse()
    |> URI.to_string()
  end

  @spec auth_url(String.t(), String.t()) :: String.t()
  def auth_url(domain, query_string) do
    domain
    |> parse()
    |> URI.append_path("/oauth2/auth")
    |> URI.append_query(query_string)
    |> URI.to_string()
  end

  @spec jwks_url(String.t()) :: String.t()
  def jwks_url(domain) do
    domain
    |> parse()
    |> URI.append_path("/.well-known/jwks")
    |> URI.to_string()
  end

  defp parse(url) when is_binary(url), do: parse(URI.parse(url))
  defp parse(url = %URI{scheme: nil}), do: parse("https://#{to_string(url)}")
  defp parse(url = %URI{path: nil}), do: parse("#{to_string(url)}/")
  defp parse(url), do: url
end
