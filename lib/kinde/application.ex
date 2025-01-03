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
        Kinde.StateManagementAgent,
        Kinde.TokenStrategy,
        {Kinde.ManagementAPI, management_api()}
      ]

    opts = [strategy: :one_for_one, name: Kinde.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp management_api do
    opts =
      :kinde
      |> Application.get_env(Kinde.ManagementAPI, [])
      |> Keyword.take(~w[client_id client_secret]a)

    case Application.fetch_env(:kinde, :domain) do
      {:ok, domain} ->
        Keyword.put_new(opts, :business_domain, domain)

      :error ->
        opts
    end
  end
end
