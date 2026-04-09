defmodule Kinde.ManagementAPI do
  @moduledoc """
  Client for the [Kinde Management API](https://docs.kinde.com/kinde-apis/management/).

  Starts as a GenServer under the application supervisor and automatically
  obtains and renews an access token using the client credentials flow.

  ## Configuration

      config :kinde, :management_api,
        client_id: "management_client_id",
        client_secret: "management_client_secret",
        business_domain: "https://yourapp.kinde.com"  # defaults to :domain

  If `:business_domain` is not set, the top-level `:domain` config value is used.

  The server returns `:ignore` on startup when required keys are missing, so the
  application can still boot without Management API credentials.
  """

  use GenServer

  alias Kinde.{APIError, NoAccessTokenError, ObtainingTokenError}

  require Logger

  @finch_name Kinde.Finch

  @retry_timeout :timer.minutes(5)

  @doc """
  Fetches a user by their Kinde ID.

  Returns `{:ok, user_map}` on success, `{:error, %APIError{}}` on API errors,
  or `{:error, %NoAccessTokenError{}}` if the access token hasn't been obtained yet.

  ## Examples

      iex> Kinde.ManagementAPI.get_user("kp_abc123def456")
      {:ok, %{"first_name" => "Mary", "last_name" => "Doe", ...}}

  """
  @spec get_user(String.t(), GenServer.server()) :: {:ok, map()} | {:error, term()}
  def get_user(kinde_id, server \\ __MODULE__) do
    with {:ok, request} <- GenServer.call(server, :build_request),
         {:ok, response} <- Req.request(request, url: "/api/v1/user", params: [id: kinde_id]) do
      %Req.Response{status: status, body: body} = response
      handle_response(status, body)
    end
  end

  @doc """
  Deletes all MFA settings for a user.

  Returns `:ok` on success, `{:error, %APIError{}}` on API errors,
  or `{:error, %NoAccessTokenError{}}` if the access token hasn't been obtained yet.

  ## Examples

      iex> Kinde.ManagementAPI.delete_mfa("kp_abc123def456")
      :ok

  """
  @spec delete_mfa(String.t(), GenServer.server()) :: :ok | {:error, term()}
  def delete_mfa(kinde_id, server \\ __MODULE__) do
    with {:ok, request} <- GenServer.call(server, :build_request),
         {:ok, response} <-
           Req.request(request, url: "/api/v1/users/#{kinde_id}/mfa", method: :delete),
         %Req.Response{status: status, body: body} = response,
         {:ok, _body} <- handle_response(status, body) do
      :ok
    end
  end

  @doc """
  Fetches all users, handling pagination automatically.

  Returns `{:ok, [user_map]}` with a flat list of all users across all pages.

  ## Examples

      iex> Kinde.ManagementAPI.list_users()
      {:ok, [%{"first_name" => "John", ...}, %{"first_name" => "Jane", ...}]}

  """
  @spec list_users(GenServer.server()) :: {:ok, [map()]} | {:error, term()}
  def list_users(server \\ __MODULE__) do
    with {:ok, request} <- GenServer.call(server, :build_request) do
      list_users([], nil, request)
    end
  end

  defp list_users(users, next_token, %Req.Request{} = request) do
    params = build_params(next_token)

    with {:ok, response} <- Req.request(request, url: "/api/v1/users", params: params),
         %Req.Response{status: status, body: body} = response,
         {:ok, payload} <- handle_response(status, body) do
      handle_users_response(payload, users, request)
    end
  end

  defp build_params(nil) do
    []
  end

  defp build_params(next_token) do
    [next_token: next_token]
  end

  defp handle_users_response(%{"users" => batch, "next_token" => nil}, users, _server) do
    handle_users_list([batch | users])
  end

  defp handle_users_response(%{"users" => batch, "next_token" => next_token}, users, server) do
    list_users([batch | users], next_token, server)
  end

  defp handle_users_list(nested_list) do
    nested_list
    |> Enum.reject(&is_nil/1)
    |> Enum.reverse()
    |> List.flatten()
    |> then(fn unnested_list -> {:ok, unnested_list} end)
  end

  defp handle_response(200, body) do
    {:ok, body}
  end

  defp handle_response(status, %{"errors" => errors}) when is_list(errors) do
    {:error, %APIError{status: status, errors: errors}}
  end

  defp handle_response(status, body) do
    {:error, %APIError{status: status, errors: [body]}}
  end

  @doc false
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    case init_state(opts) do
      {:ok, state} ->
        send(self(), :renew)
        {:ok, state}

      :error ->
        :ignore
    end
  end

  @impl GenServer
  def handle_info(:renew, state) do
    case renew_state(state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, _reason} ->
        {:noreply, %{state | renew_token_timer: schedule_renew_token(@retry_timeout)}}
    end
  end

  @impl GenServer
  def handle_call(:build_request, _from, %{access_token: nil} = state) do
    {:reply, {:error, %NoAccessTokenError{}}, state}
  end

  def handle_call(:build_request, _from, state) do
    %{access_token: access_token, business_domain: business_domain, req_opts: req_opts} = state
    {:reply, {:ok, build_api_request(business_domain, access_token, req_opts)}, state}
  end

  defp init_state(opts) do
    with {:ok, client_id} <- Keyword.fetch(opts, :client_id),
         {:ok, client_secret} <- Keyword.fetch(opts, :client_secret),
         {:ok, business_domain} <- Keyword.fetch(opts, :business_domain) do
      {:ok,
       %{
         business_domain: business_domain,
         client_secret: client_secret,
         client_id: client_id,
         req_opts: Keyword.get(opts, :req_opts, []),
         renew_token_timer: nil,
         access_token: nil
       }}
    end
  end

  defp renew_state(state) do
    %{
      business_domain: business_domain,
      client_secret: client_secret,
      client_id: client_id,
      req_opts: req_opts
    } = state

    payload = auth_payload(client_id, client_secret, business_domain)
    request = build_oauth_request(business_domain, payload, req_opts)

    with {:ok, %Req.Response{status: status, body: body}} <- Req.request(request) do
      renew_token(status, body, state)
    end
  end

  defp renew_token(200, %{"access_token" => access_token, "expires_in" => expires_in}, state) do
    Logger.info("Access token obtained successfully")

    renew_token_timer =
      expires_in
      |> :timer.seconds()
      |> schedule_renew_token()

    state =
      state
      |> Map.put(:access_token, access_token)
      |> Map.put(:renew_token_timer, renew_token_timer)

    {:ok, state}
  end

  defp renew_token(status, body, _state) do
    error = %ObtainingTokenError{status: status, body: body}
    Logger.error(Exception.message(error))
    {:error, error}
  end

  defp schedule_renew_token(timeout) do
    Process.send_after(self(), :renew, timeout)
  end

  defp auth_payload(client_id, client_secret, business_domain) do
    %{
      grant_type: :client_credentials,
      client_id: client_id,
      client_secret: client_secret,
      audience: "#{business_domain}/api"
    }
  end

  defp build_request(business_domain, req_opts) do
    req_opts
    |> Req.new()
    |> Req.Request.merge_options(finch: @finch_name, base_url: business_domain)
  end

  defp build_oauth_request(business_domain, payload, req_opts) do
    business_domain
    |> build_request(req_opts)
    |> Req.merge(form: payload, url: "/oauth2/token", method: :post)
  end

  defp build_api_request(business_domain, access_token, req_opts) do
    business_domain
    |> build_request(req_opts)
    |> Req.Request.put_header("accept", "application/json")
    |> Req.merge(auth: {:bearer, access_token})
  end
end
