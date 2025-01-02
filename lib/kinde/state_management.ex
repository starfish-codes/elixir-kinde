defmodule Kinde.StateManagement do
  @moduledoc """
  Behaviour that abstracts state management
  """

  @callback put_state(String.t(), Kinde.state_params()) :: :ok
  @callback take_state(String.t()) :: {:ok, Kinde.state_params()} | {:error, term()}
  @callback cleanup_state(String.t()) :: :ok | {:error, term()}
end
