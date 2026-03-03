defmodule Kinde.StateNotFoundError do
  @moduledoc """
  Returned by `Kinde.token/4` when the OAuth state parameter is not found
  in state management (expired, already consumed, or never created).
  """

  @type t() :: %__MODULE__{
          state: String.t()
        }

  defexception [:state]

  @impl Exception
  def message(%__MODULE__{state: state}) do
    "OIDC state was not found: " <> state
  end
end
