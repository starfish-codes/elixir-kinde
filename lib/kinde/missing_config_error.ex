defmodule Kinde.MissingConfigError do
  @moduledoc """
  Returned when required configuration keys (`:domain`, `:client_id`,
  `:client_secret`, `:redirect_uri`) are missing from both the function
  arguments and the application environment.
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
