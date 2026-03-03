defmodule Kinde do
  @moduledoc """
  Supports OpenID Connect with PKCE
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

  @scopes ~w[openid profile email offline]
  @config_keys ~w[domain client_id client_secret redirect_uri]a

  @finch_name Kinde.Finch

  @doc """
  Generates the OAuth2 redirect url

  ### Examples

      iex> auth(%{domain: "https://myapp...", client_id: "value", client_secret: "value", redirect_uri: "value"})
      {:ok, "https://myapp.com/oauth2/auth?"}

      iex> auth(%{client_id: "value", client_secret: "value", redirect_uri: "value"})
      {:error, :missing_config_key}

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
  Returns the token for Kinde Client
  """
  @spec token(String.t(), String.t(), config(), Keyword.t()) ::
          {:ok, map(), map()} | {:error, term()}
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
         {:ok, claims} <- handle_response(response) do
      {:ok, user_params(claims), extra_params}
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

  defp handle_response(%Req.Response{status: 200, body: %{"id_token" => token}}) do
    Token.verify_and_validate(token)
  end

  defp handle_response(%Req.Response{status: status, body: body}) do
    {:error, %ObtainingTokenError{status: status, body: body}}
  end

  defp user_params(claims) do
    %{
      id: claims["sub"],
      given_name: claims["given_name"],
      family_name: claims["family_name"],
      email: claims["email"],
      picture: claims["picture"]
    }
  end

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
