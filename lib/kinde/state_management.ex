defmodule Kinde.StateManagement do
  @moduledoc """
  Behaviour for storing and retrieving OAuth state and PKCE code verifiers.

  The default implementation is `Kinde.StateManagementAgent`, which stores
  state in-memory using an `Agent`. For multi-node deployments, provide a
  custom implementation backed by Redis, a database, or another shared store.

  ## Custom implementation (Ecto)

  Create a migration:

      defmodule MyApp.Repo.Migrations.CreateOAuthStates do
        use Ecto.Migration

        def change do
          create table(:oauth_states, primary_key: false) do
            add :state, :string, primary_key: true
            add :code_verifier, :string, null: false
            add :extra_params, :map, null: false, default: %{}

            timestamps(updated_at: false)
          end
        end
      end

  Define a schema and the behaviour implementation:

      defmodule MyApp.OAuthState do
        use Ecto.Schema

        @primary_key {:state, :string, autogenerate: false}
        schema "oauth_states" do
          field :code_verifier, :string
          field :extra_params, :map, default: %{}

          timestamps(updated_at: false)
        end
      end

      defmodule MyApp.EctoStateManagement do
        @behaviour Kinde.StateManagement

        alias MyApp.{OAuthState, Repo}

        @impl true
        def put_state(state, %{code_verifier: code_verifier, extra_params: extra_params}) do
          Repo.insert!(%OAuthState{
            state: state,
            code_verifier: code_verifier,
            extra_params: extra_params
          })
        end

        @impl true
        def take_state(state) do
          case Repo.get(OAuthState, state) do
            nil ->
              {:error, %Kinde.StateNotFoundError{state: state}}

            record ->
              Repo.delete(record)
          end
        end
      end

  Then configure it:

      # config/runtime.exs
      config :kinde, :state_management_impl, MyApp.EctoStateManagement

  `take_state/1` must read and delete the entry (one-time use).
  """

  @callback put_state(String.t(), Kinde.state_params()) :: :ok
  @callback take_state(String.t()) :: {:ok, Kinde.state_params()} | {:error, term()}

  @spec put_state(String.t(), Kinde.state_params()) :: :ok
  def put_state(state, params) do
    impl().put_state(state, params)
  end

  @spec take_state(String.t()) ::
          {:ok, Kinde.state_params()} | {:error, Kinde.StateNotFoundError.t()}
  def take_state(state) do
    impl().take_state(state)
  end

  defp impl do
    Application.get_env(:kinde, :state_management_impl, Kinde.StateManagementAgent)
  end
end
