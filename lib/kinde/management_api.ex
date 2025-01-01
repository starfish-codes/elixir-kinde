defmodule Kinde.ManagementAPI do
  @moduledoc false
  @behaviour __MODULE__

  use Tesla
  use GenServer

  require Logger

  @finch_name KindeFinch

  adapter Tesla.Adapter.Finch, name: @finch_name

  plug Tesla.Middleware.Telemetry
  plug Tesla.Middleware.Logger

  @callback get_user(String.t()) :: {:ok, map()} | {:error, term()}
  @callback list_users() :: {:ok, [map()]} | {:error, term()}

  @retry_timeout :timer.minutes(5)

  @impl __MODULE__
  def get_user(kinde_id) do
    with {_request, %Req.Response{status: status, body: body}} <-
           Req.run(request(), url: "/api/v1/user?id=#{kinde_id}") do
      handle_response(status, body)
    end
  end

  @impl __MODULE__
  def list_users, do: list_users([], nil)

  defp list_users(users, next_token) do
    with {_request, %Req.Response{status: status, body: body}} <-
           Req.run(request(), url: users_url(next_token)),
         {:ok, payload} <- handle_response(status, body) do
      handle_users_response(payload, users)
    end
  end

  defp handle_users_response(%{"users" => nil, "next_token" => nil}, users),
    do: handle_users_list(users)

  defp handle_users_response(%{"users" => batch, "next_token" => nil}, users),
    do: handle_users_list([batch | users])

  defp handle_users_response(%{"users" => batch, "next_token" => next_token}, users),
    do: list_users([batch | users], next_token)

  defp handle_users_list(nested_list) do
    nested_list
    |> Enum.reverse()
    |> List.flatten()
    |> then(&{:ok, &1})
  end

  defp users_url(nil), do: "/api/v1/users"
  defp users_url(next_token), do: "/api/v1/users?next_token=#{next_token}"

  defp request, do: GenServer.call(__MODULE__, :http_client)

  defp handle_response(200, body) do
    {:ok, body}
  end

  defp handle_response(_status, %{"errors" => errors}) do
    Enum.each(errors, fn
      %{"code" => code, "message" => message} ->
        Logger.error("Kinde Management API #{code} error: #{message}")

      unexpected_error ->
        Logger.error("Kinde Management API unexpected error: " <> inspect(unexpected_error))
    end)

    {:error, :kinde_api_error_response}
  end

  defp handle_response(status, body) do
    Logger.error("Unknown Kinde Management API #{status} error: " <> inspect(body))
    {:error, :kinde_api_unknown_error}
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl GenServer
  def init(opts), do: {:ok, opts, {:continue, :init_state}}

  @impl GenServer
  def handle_continue(:init_state, opts) do
    with {:ok, client_id} <- Keyword.fetch(opts, :client_id),
         {:ok, client_secret} <- Keyword.fetch(opts, :client_secret),
         {:ok, business_domain} <- Keyword.fetch(opts, :business_domain),
         prepend_request <- Keyword.get(opts, :prepend_request, []),
         {:ok, state} <- init_state(client_id, client_secret, business_domain, prepend_request) do
      state = Map.put(state, :business_domain, business_domain)

      {:noreply, state}
    else
      reason ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call(
        :http_client,
        _from,
        %{access_token: access_token, business_domain: business_domain} = state
      ) do
    req =
      [
        base_url: business_domain,
        auth: {:bearer, access_token},
        headers: [{"accept", "application/json"}]
      ]
      |> Req.new()
      |> Req.Request.merge_options(req_options())

    {:reply, req, state}
  end

  @impl GenServer
  def handle_info(
        :renew_token,
        %{client_id: client_id, client_secret: client_secret, business_domain: business_domain} =
          state
      ) do
    case init_state(client_id, client_secret, business_domain) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, _reason} ->
        {:noreply, %{state | renew_token_timer: schedule_renew_token(@retry_timeout)}}
    end
  end

  defp auth_payload(client_id, client_secret, business_domain) do
    %{
      grant_type: :client_credentials,
      client_id: client_id,
      client_secret: client_secret,
      audience: "#{business_domain}/api"
    }
  end

  defp init_state(client_id, client_secret, business_domain, prepend_request \\ []) do
    payload = auth_payload(client_id, client_secret, business_domain)

    request =
      [form: payload, base_url: business_domain, url: "/oauth2/token", method: :post]
      |> Req.new()
      |> Req.Request.merge_options(req_options())
      |> Req.Request.prepend_request_steps(prepend_request)

    with {_request, %Req.Response{status: status, body: body}} <- Req.run(request),
         do: init_state(status, body, client_id, client_secret, prepend_request)
  end

  defp init_state(
         200,
         %{"access_token" => access_token, "expires_in" => expires_in},
         client_id,
         client_secret,
         _prepend_request
       ) do
    Logger.info("Access token obtained successfully")

    {:ok,
     %{
       client_id: client_id,
       client_secret: client_secret,
       access_token: access_token,
       renew_token_timer: expires_in |> :timer.seconds() |> schedule_renew_token()
     }}
  end

  defp init_state(
         _status,
         %{"error" => error, "error_description" => description},
         _client_id,
         _client_secret,
         _prepend_request
       ) do
    Logger.error("Kinde error: #{description}")
    {:error, error}
  end

  defp init_state(status, body, _client_id, _client_secret, _prepend_request) do
    Logger.error("Unknown Kinde #{status} error: " <> inspect(body))
    {:error, :unknown_kinde_error}
  end

  defp schedule_renew_token(timeout), do: Process.send_after(self(), :renew_token, timeout)

  defp req_options, do: Application.get_env(:kinde, :management_api_req_options, [])
end
