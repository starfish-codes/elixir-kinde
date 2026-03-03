defmodule Kinde.MissingConfigError do
  @moduledoc """
  Missing config keys detected
  """

  @type t() :: %__MODULE__{
          keys: [atom()]
        }

  defexception [:keys]

  @impl Exception
  def message(%__MODULE__{keys: keys}) do
    "Missing kinde configuration keys: " <> Enum.join(keys, ", ")
  end
end
