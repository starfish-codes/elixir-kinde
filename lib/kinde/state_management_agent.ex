defmodule Kinde.StateManagementAgent do
  @moduledoc """
  Default in-memory state management using `Agent`.

  Suitable for single-node deployments. For multi-node setups, implement
  the `Kinde.StateManagement` behaviour with a shared store.
  """

  @behaviour Kinde.StateManagement

  use Agent

  @spec start_link(Keyword.t()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(&Map.new/0, name: __MODULE__)
  end

  @impl Kinde.StateManagement
  def put_state(state, params) do
    Agent.update(__MODULE__, &Map.put(&1, state, params))
  end

  @impl Kinde.StateManagement
  def take_state(state) do
    case Agent.get_and_update(__MODULE__, &Map.pop(&1, state)) do
      nil ->
        {:error, %Kinde.StateNotFoundError{state: state}}

      params ->
        {:ok, params}
    end
  end
end
