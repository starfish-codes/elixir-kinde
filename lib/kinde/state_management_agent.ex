defmodule Kinde.StateManagementAgent do
  @moduledoc """
  Simple State Management implementation. Used by default
  """

  @behaviour Kinde.StateManagement

  use Agent

  @spec start_link(Keyword.t()) :: Agent.on_start()
  def start_link([]), do: Agent.start_link(&Map.new/0, name: __MODULE__)

  @impl Kinde.StateManagement
  def put_state(state, params), do: Agent.update(__MODULE__, &Map.put(&1, state, params))

  @impl Kinde.StateManagement
  def take_state(state), do: {:ok, Agent.get_and_update(__MODULE__, &Map.pop!(&1, state))}

  @impl Kinde.StateManagement
  def cleanup_state(state), do: Agent.update(__MODULE__, &Map.delete(&1, state))
end
