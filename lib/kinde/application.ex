defmodule Kinde.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @jwks_url Application.compile_env!(:kinde, :jwks_url)

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: KindeFinch},
      Kinde.StateManagementAgent,
      {Kinde.TokenStrategy, [jwks_url: @jwks_url]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Kinde.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
