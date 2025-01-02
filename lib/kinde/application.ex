defmodule Kinde.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Finch, name: Kinde.Finch},
        Kinde.StateManagementAgent
      ] ++ token_strategy() ++ management_api()

    opts = [strategy: :one_for_one, name: Kinde.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp token_strategy do
    if Application.get_env(:kinde, :token_strategy, false) do
      [Kinde.TokenStrategy]
    else
      []
    end
  end

  defp management_api do
    if Application.get_env(:kinde, :management_api, false) do
      [{Kinde.ManagementApi, management_api_opts()}]
    else
      []
    end
  end

  defp management_api_opts,
    do: Enum.reduce(~w[business_domain client_id client_secret]a, [], &put_config/2)

  defp put_config(key, opts) do
    case Application.fetch_env(:kinde, key) do
      {:ok, value} ->
        Keyword.put(opts, key, value)

      :error ->
        opts
    end
  end
end
