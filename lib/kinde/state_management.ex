defmodule Kinde.StateManagement do
  @moduledoc """

  """

  @callback put_state(String.t(), Kinde.state_params()) :: :ok
  @callback take_state(String.t()) :: {:ok, Kinde.state_params()} | {:error, term()}
end
