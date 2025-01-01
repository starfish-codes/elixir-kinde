defmodule Kinde.ManagementAPI do
  @moduledoc false

  use GenServer

  require Logger

  @finch_name KindeFinch

  @retry_timeout :timer.minutes(5)

  @spec get_user(String.t(), GenServer.server()) :: {:ok, map()} | {:error, term()}
  def get_user(kinde_id, server \\ __MODULE__) do
    request = request(server)

    with {:ok, response} <- Req.request(request, url: "/api/v1/user?id=#{kinde_id}") do
      %Req.Response{status: status, body: body} = response
      handle_response(status, body)
    end
  end

  @spec list_users(GenServer.server()) :: {:ok, [map()]} | {:error, term()}
  def list_users(server \\ __MODULE__),
    do: list_users([], nil, server)

  defp list_users(users, next_token, server) do
    request = request(server)

    with {:ok, response} <- Req.request(request, url: users_url(next_token)),
         %Req.Response{status: status, body: body} = response,
         {:ok, payload} <- handle_response(status, body) do
      handle_users_response(payload, users, server)
    end
  end

  defp handle_users_response(%{"users" => nil, "next_token" => nil}, users, _server),
    do: handle_users_list(users)

  defp handle_users_response(%{"users" => batch, "next_token" => nil}, users, _server),
    do: handle_users_list([batch | users])

  defp handle_users_response(%{"users" => batch, "next_token" => next_token}, users, server),
    do: list_users([batch | users], next_token, server)

  defp handle_users_list(nested_list) do
    nested_list
    |> Enum.reverse()
    |> List.flatten()
    |> then(&{:ok, &1})
  end

  defp users_url(nil), do: "/api/v1/users"
  defp users_url(next_token), do: "/api/v1/users?next_token=#{next_token}"

  defp request(server), do: GenServer.call(server, :build_request)

  defp handle_response(200, body), do: {:ok, body}

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
  def init(opts) do
    case required_configuration(opts) do
      {:ok, config} ->
        {:ok, Map.put(config, :opts, opts), {:continue, :init_state}}

      :error ->
        # TODO: make it more informative
        {:stop, :missing_required_configuration}
    end
  end

  @impl GenServer
  def handle_continue(:init_state, state) do
    case init_state(state) do
      {:ok, state} ->
        {:noreply, state}

      {:error, reason} ->
        raise "Don't know what to do yet with #{reason}"
    end
  end

  @impl GenServer
  def handle_call(
        :build_request,
        _from,
        %{access_token: access_token, business_domain: business_domain, opts: opts} = state
      ),
      do: {:reply, build_api_request(business_domain, access_token, opts), state}

  @impl GenServer
  def handle_info(:renew_token, state) do
    case init_state(state) do
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

  defp init_state(
         %{
           client_id: client_id,
           client_secret: client_secret,
           business_domain: business_domain,
           opts: opts
         } = state
       ) do
    payload = auth_payload(client_id, client_secret, business_domain)
    request = build_oauth_request(business_domain, payload, opts)

    with {:ok, %Req.Response{status: status, body: body}} <- Req.request(request) do
      init_state(status, body, state)
    end
  end

  defp init_state(200, %{"access_token" => access_token, "expires_in" => expires_in}, state) do
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

  defp init_state(_status, %{"error" => error, "error_description" => description}, _state) do
    Logger.error("Kinde error: #{description}")
    {:error, error}
  end

  defp init_state(status, body, _state) do
    Logger.error("Unknown Kinde #{status} error: " <> inspect(body))
    {:error, :unknown_kinde_error}
  end

  defp required_configuration(opts) do
    with {:ok, client_id} <- Keyword.fetch(opts, :client_id),
         {:ok, client_secret} <- Keyword.fetch(opts, :client_secret),
         {:ok, business_domain} <- Keyword.fetch(opts, :business_domain) do
      {:ok,
       %{
         client_id: client_id,
         client_secret: client_secret,
         business_domain: business_domain
       }}
    end
  end

  defp schedule_renew_token(timeout), do: Process.send_after(self(), :renew_token, timeout)

  defp build_request(business_domain, opts) do
    :kinde
    |> Application.get_env(__MODULE__, [])
    |> Keyword.merge(
      finch: @finch_name,
      base_url: business_domain
    )
    |> Req.new()
    |> Req.Request.register_options([:owner])
    |> Req.Request.merge_options(Keyword.take(opts, [:owner]))
    |> Req.Request.prepend_request_steps(allow_ownership: &allow_ownership/1)
  end

  defp build_oauth_request(business_domain, payload, opts) do
    business_domain
    |> build_request(opts)
    |> Req.merge(form: payload, url: "/oauth2/token", method: :post)
  end

  defp build_api_request(business_domain, access_token, opts) do
    business_domain
    |> build_request(opts)
    |> Req.merge(auth: {:bearer, access_token})
    |> Req.Request.put_header("accept", "application/json")
  end

  defp allow_ownership(request) do
    tap(request, fn req ->
      with {Req.Test, mock} <- Req.Request.get_option(req, :plug),
           owner when is_pid(owner) <- Req.Request.get_option(req, :owner) do
        Req.Test.allow(mock, owner, self())
      end
    end)
  end
end
