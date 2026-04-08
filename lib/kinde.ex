defmodule Kinde do
  @moduledoc """
  OpenID Connect authentication with PKCE for [Kinde](https://kinde.com).

  Provides two main functions:

    * `auth/2` — generates an OAuth2 authorization URL and stores the PKCE
      code verifier in state management
    * `token/4` — exchanges the authorization code for an ID token,
      verifies it, and returns user attributes

  ## Configuration

  Required keys can be set via application config or passed directly as a map:

      config :kinde,
        domain: "https://yourapp.kinde.com",
        client_id: "client_id",
        client_secret: "client_secret",
        redirect_uri: "http://localhost:4000/callback"

  When a map is passed to `auth/2` or `token/4`, its values take precedence
  over the application config. See the "All configuration keys" section in
  the README for a complete reference.

  ## Example

      # Step 1: redirect user to Kinde
      {:ok, url} = Kinde.auth()

      # Step 2: handle the callback
      {:ok, token_response, extra_params} = Kinde.token(code, state)
  """

  alias Kinde.{MissingConfigError, ObtainingTokenError, StateManagement, Token, URL}

  require Logger

  @type config :: %{
          optional(:domain) => String.t(),
          optional(:client_id) => String.t(),
          optional(:client_secret) => String.t(),
          optional(:redirect_uri) => String.t(),
          optional(:prompt) => String.t(),
          optional(:scopes) => [String.t()]
        }

  @type state_params :: %{
          code_verifier: String.t(),
          extra_params: map()
        }

  @type token_response :: %{
          access_token: String.t(),
          access_token_claims: map(),
          id_token: String.t(),
          id_token_claims: map(),
          refresh_token: String.t(),
          expires_in: non_neg_integer(),
          scope: String.t(),
          token_type: String.t()
        }

  @scopes ~w[openid profile email offline]
  @config_keys ~w[domain client_id client_secret redirect_uri]a

  @finch_name Kinde.Finch

  @doc """
  Generates an OAuth2 authorization URL with PKCE.

  Accepts an optional `config` map (overrides app env) and an optional
  `extra_params` map that will be returned alongside user data after
  a successful `token/4` call.

  Returns `{:ok, url}` on success or `{:error, %MissingConfigError{}}` when
  required configuration keys are missing.

  ## Examples

      iex> Kinde.auth()
      {:ok, "https://yourapp.kinde.com/oauth2/auth?..."}

      iex> Kinde.auth(%{}, %{return_to: "/dashboard"})
      {:ok, "https://yourapp.kinde.com/oauth2/auth?..."}

  """
  @spec auth(config(), map()) :: {:ok, String.t()} | {:error, term()}
  def auth(config \\ %{}, extra_params \\ %{}) do
    with {:ok, config} <- load_config_from_app_env(config),
         {verifier, challenge} = pkce(),
         {:ok, state} <- create_state(verifier, extra_params) do
      auth(config, challenge, state)
    end
  end

  defp auth(%{domain: domain} = config, challenge, state) do
    scope =
      config
      |> Map.get(:scopes, @scopes)
      |> Enum.join(" ")

    qs = build_query_string(config, scope, state, challenge)

    {:ok, URL.auth_url(domain, qs)}
  end

  @doc """
  Exchanges an authorization code for user attributes.

  Takes the `code` and `state` from the Kinde callback, verifies the ID token
  via JWKS, and returns user attributes along with any `extra_params` that were
  passed to `auth/2`.

  Returns `{:ok, token_response, extra_params}` on success, where
  `token_response` is a `t:token_response/0` map containing the full OAuth2
  token endpoint response including decoded JWT claims.

  ## Errors

    * `{:error, %ObtainingTokenError{}}` — the token endpoint returned an error
    * `{:error, %StateNotFoundError{}}` — the state was not found (expired or already used)
    * `{:error, %MissingConfigError{}}` — required config keys are missing
  """
  @spec token(String.t(), String.t(), config(), Keyword.t()) ::
          {:ok, token_response(), map()} | {:error, term()}
  def token(code, state, config \\ %{}, opts \\ []) do
    with {:ok, config} <- load_config_from_app_env(config),
         {:ok, params} <- StateManagement.take_state(state) do
      fetch_token(config, code, params, opts)
    end
  end

  defp fetch_token(config, code, params, opts) do
    %{
      domain: domain,
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri
    } = config

    %{
      code_verifier: code_verifier,
      extra_params: extra_params
    } = params

    form = %{
      grant_type: "authorization_code",
      code: code,
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      code_verifier: code_verifier
    }

    with {:ok, response} <- run_request(domain, form, opts),
         {:ok, token_response} <- decode_token_response(response) do
      {:ok, token_response, extra_params}
    end
  end

  defp run_request(domain, form, opts) do
    opts
    |> Keyword.put(:url, "/oauth2/token")
    |> Keyword.put(:base_url, URL.base_url(domain))
    |> Keyword.put(:form, form)
    |> Keyword.put(:finch, @finch_name)
    |> Req.post()
  end

  defp decode_token_response(%Req.Response{status: 200, body: body}) do
    with {:ok, id_token_claims} <- verify_token(body["id_token"]),
         {:ok, access_token_claims} <- verify_token(body["access_token"]) do
      {:ok,
       %{
         access_token: body["access_token"],
         access_token_claims: access_token_claims,
         id_token: body["id_token"],
         id_token_claims: id_token_claims,
         refresh_token: body["refresh_token"],
         expires_in: body["expires_in"],
         scope: body["scope"],
         token_type: body["token_type"]
       }}
    end
  end

  defp decode_token_response(%Req.Response{status: status, body: body}) do
    {:error, %ObtainingTokenError{status: status, body: body}}
  end

  defp verify_token(nil), do: {:ok, %{}}
  defp verify_token(token), do: Token.verify_and_validate(token)

  defp pkce do
    verifier =
      64
      |> :crypto.strong_rand_bytes()
      |> Base.encode16(case: :lower)

    challenge =
      :sha256
      |> :crypto.hash(verifier)
      |> Base.url_encode64(padding: false)

    {verifier, challenge}
  end

  defp generate_state do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
  end

  defp create_state(verifier, extra_params) do
    state = generate_state()
    params = %{code_verifier: verifier, extra_params: extra_params}

    with :ok <- StateManagement.put_state(state, params) do
      {:ok, state}
    end
  end

  defp build_query_string(config, scope, state, challenge) do
    config
    |> Map.take(~w[client_id redirect_uri prompt]a)
    |> Map.put_new(:prompt, "login")
    |> Map.put(:response_type, :code)
    |> Map.put(:scope, scope)
    |> Map.put(:state, state)
    |> Map.put(:code_challenge, challenge)
    |> Map.put(:code_challenge_method, "S256")
    |> URI.encode_query()
  end

  defp load_config_from_app_env(config) do
    @config_keys
    |> Enum.reduce(config, &load_config_from_app_env/2)
    |> check_config()
  end

  defp load_config_from_app_env(key, acc) do
    case Application.fetch_env(:kinde, key) do
      {:ok, value} ->
        Map.put_new(acc, key, value)

      :error ->
        acc
    end
  end

  defp check_config(config) do
    case Enum.reject(@config_keys, fn key -> Map.has_key?(config, key) end) do
      [] ->
        {:ok, config}

      missing_keys ->
        {:error, %MissingConfigError{keys: missing_keys}}
    end
  end
end
