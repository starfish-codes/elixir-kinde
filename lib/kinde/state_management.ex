defmodule Kinde.StateManagement do
  @moduledoc """
  Behaviour that abstracts state management
  """

  @callback put_state(String.t(), Kinde.state_params()) :: :ok
  @callback take_state(String.t()) :: {:ok, Kinde.state_params()} | {:error, term()}

  @spec put_state(String.t(), Kinde.state_params()) :: :ok
  def put_state(state, params), do: impl().put_state(state, params)

  @spec take_state(String.t()) :: {:ok, Kinde.state_params()} | {:error, term()}
  def take_state(state), do: impl().take_state(state)

  defp impl, do: Application.get_env(:kinde, __MODULE__, Kinde.StateManagementAgent)
end
