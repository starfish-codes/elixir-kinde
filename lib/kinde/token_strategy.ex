defmodule Kinde.TokenStrategy do
  @moduledoc """
  JWKS strategy to verify access token. This is default strategy for the Kinde.IdToken

  See https://docs.kinde.com/developer-tools/about/using-kinde-without-an-sdk/#verifying-the-kinde-access-token
  """

  use JokenJwks.DefaultStrategyTemplate

  @spec init_opts(opts :: Keyword.t()) :: Keyword.t()
  def init_opts(opts) do
    opts
    |> put_jwks_url()
    |> Keyword.put_new(:explicit_alg, "RS256")
  end

  defp put_jwks_url(opts) do
    if Keyword.has_key?(opts, :jwks_url) do
      opts
    else
      Keyword.put(opts, :jwks_url, build_jwks_url())
    end
  end

  defp build_jwks_url do
    business_domain = Application.fetch_env!(:kinde, :business_domain)
    "https://#{business_domain}/.well-known/jwks"
  end
end
