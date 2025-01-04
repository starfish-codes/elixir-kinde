defmodule Kinde do
  @moduledoc """
  Supports OpenID Connect with PKCE
  """

  alias Kinde.Token
  alias Kinde.StateManagement

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
  def auth(config, extra_params \\ %{}) do
    config = load_config_from_app_env(config)

    with :ok <- check_config(config),
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
    {:ok, "#{domain}/oauth2/auth?#{qs}"}
  end

  @doc """
  Returns the token for Kinde Client

  ### Examples

      iex> token(%{client_id: "value"}, "base64code", "state_hash")
      {:ok, %{given_name: "John"}, %{extra_params: "additional data"}}

      iex> auth(%{client_id: "value", client_secret: "value", redirect_uri: "value"})
      {:error, :missing_config_key}
  """
  @spec token(config(), String.t(), map()) :: {:ok, map(), map()} | {:error, term()}
  def token(config \\ %{}, code, state) when is_binary(state) do
    config = load_config_from_app_env(config)

    with :ok <- check_config(config),
         {:ok, params} <- take_state(state) do
      fetch_token(config, code, params)
    end
  end

  defp fetch_token(config, code, %{code_verifier: code_verifier, extra_params: extra_params}) do
    %{
      domain: domain,
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri
    } = config

    params = %{
      grant_type: "authorization_code",
      code: code,
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      code_verifier: code_verifier
    }

    with {:ok, response} <- token_request(domain, params),
         {:ok, claims} <- token_response(response) do
      {:ok, user_params(claims), extra_params}
    end
  end

  defp token_request(base_url, params) do
    opts =
      :kinde
      |> Application.get_env(__MODULE__, [])
      |> Keyword.put(:base_url, base_url)
      |> Keyword.put(:form, params)
      |> Keyword.put(:finch, @finch_name)

    Req.post("/oauth2/token", opts)
  end

  defp token_response(%Req.Response{status: 200, body: body}) do
    body
    |> Map.fetch!("id_token")
    |> Token.verify_and_validate()
  end

  defp token_response(%Req.Response{status: status}) do
    Logger.error("Couldn't request token: #{status}")
    {:error, :no_token}
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

  defp take_state(state), do: StateManagement.take_state(state)

  defp check_config(config) do
    @config_keys
    |> Enum.all?(fn key -> Map.has_key?(config, key) end)
    |> if(do: :ok, else: {:error, :missing_config_key})
  end

  defp load_config_from_app_env(config) do
    Enum.reduce(@config_keys, config, fn key, acc ->
      case Application.fetch_env(:kinde, key) do
        {:ok, value} -> Map.put_new(acc, key, value)
        :error -> acc
      end
    end)
  end
end
