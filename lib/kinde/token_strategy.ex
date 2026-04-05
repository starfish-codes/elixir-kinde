defmodule Kinde.TokenStrategy do
  @moduledoc """
  JWKS strategy for verifying ID tokens in production.

  Fetches the JSON Web Key Set from `<domain>/.well-known/jwks` and validates
  RS256 signatures. Used automatically by `Kinde.Token` unless the
  `:test_strategy` config flag is set.

  See [Kinde docs on token verification](https://docs.kinde.com/developer-tools/about/using-kinde-without-an-sdk/#verifying-the-kinde-access-token).
  """

  use JokenJwks.DefaultStrategyTemplate

  alias Kinde.URL

  require Logger

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
      {:ok, domain} when domain in ["", nil] ->
        Logger.warning("Kinde domain is configured empty — Kinde token verification is disabled")
        disable(opts)

      {:ok, domain} ->
        Keyword.put(opts, :jwks_url, URL.jwks_url(domain))

      :error ->
        disable(opts)
    end
  end

  defp disable(opts) do
    opts
    |> Keyword.put(:jwks_url, "dummy-url")
    |> Keyword.put(:first_fetch_sync, false)
    |> Keyword.put(:should_start, false)
  end
end
