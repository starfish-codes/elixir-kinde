defmodule Kinde.TokenStrategy do
  @moduledoc """
  JWKS strategy to verify access token. This is default strategy for the Kinde.IdToken

  See https://docs.kinde.com/developer-tools/about/using-kinde-without-an-sdk/#verifying-the-kinde-access-token
  """

  use JokenJwks.DefaultStrategyTemplate

  @spec init_opts(opts :: Keyword.t()) :: Keyword.t()
  def init_opts(opts) do
    opts
    |> maybe_put_jwks_url()
    |> Keyword.put_new(:explicit_alg, "RS256")
  end

  defp maybe_put_jwks_url(opts) do
    if Keyword.has_key?(opts, :jwks_url) do
      opts
    else
      put_jwks_url(opts)
    end
  end

  defp put_jwks_url(opts) do
    case Application.fetch_env(:kinde, :domain) do
      {:ok, domain} ->
        Keyword.put(opts, :jwks_url, "https://#{domain}/.well-known/jwks")

      :error ->
        opts
        |> Keyword.put(:jwks_url, true)
        |> Keyword.put(:first_fetch_sync, false)
        |> Keyword.put(:should_start, false)
    end
  end
end
