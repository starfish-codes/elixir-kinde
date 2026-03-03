defmodule Kinde.StateNotFoundError do
  @moduledoc """
  When OIDC state wasn't found
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
