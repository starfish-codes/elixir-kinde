defmodule Kinde do
  @moduledoc """
  """

  use Tesla

  alias Kinde.IdToken

  require Logger

  @type config :: %{
          required(:domain) => String.t(),
          required(:client_id) => String.t(),
          required(:client_secret) => String.t(),
          required(:redirect_uri) => String.t(),
          optional(:prompt) => String.t(),
          optional(:scopes) => [String.t()]
        }

  @type state_params :: %{
          code_verifier: String.t(),
          extra_params: String.t()
        }

  @scopes ~w[openid profile email offline]
  @config_keys ~w[domain client_id client_secret redirect_uri]a

  @state_management Application.compile_env(:kinde, :state_management, Kinde.StateManagementAgent)

  adapter Tesla.Adapter.Finch, name: KindeFinch

  plug Tesla.Middleware.EncodeFormUrlencoded
  plug Tesla.Middleware.DecodeJson
  plug Tesla.Middleware.Logger

  @spec auth(config(), map()) :: {:ok, String.t()} | {:error, term()}
  def auth(config, extra_params \\ %{}) do
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

    qs =
      config
      |> Map.take(~w[client_id redirect_uri prompt]a)
      |> Map.put_new(:prompt, "login")
      |> Map.put(:response_type, :code)
      |> Map.put(:scope, scope)
      |> Map.put(:state, state)
      |> Map.put(:code_challenge, challenge)
      |> Map.put(:code_challenge_method, "S256")
      |> URI.encode_query()

    {:ok, "#{domain}/oauth2/auth?#{qs}"}
  end

  @spec token(config(), String.t(), map()) :: {:ok, map(), map()} | {:error, term()}
  def token(config, code, state) when is_binary(state) do
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
    [{Tesla.Middleware.BaseUrl, base_url}]
    |> Tesla.client()
    |> post("/oauth2/token", params)
  end

  defp token_response(%Tesla.Env{status: 200, body: body}) do
    body
    |> Map.fetch!("id_token")
    |> IdToken.verify_and_validate()
  end

  defp token_response(%Tesla.Env{status: status}) do
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

    with :ok <- @state_management.put_state(state, params) do
      {:ok, state}
    end
  end

  defp take_state(state), do: @state_management.take_state(state)

  defp check_config(config) do
    @config_keys
    |> Enum.all?(fn key -> Map.has_key?(config, key) end)
    |> if(do: :ok, else: {:error, :missing_config_key})
  end
end
