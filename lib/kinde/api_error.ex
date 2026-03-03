defmodule Kinde.APIError do
  @moduledoc """
  Represents Kinde API errored response
  """

  @type t() :: %__MODULE__{
          status: Mint.Types.status(),
          errors: list()
        }

  defexception [:status, :errors]

  @impl Exception
  def message(%__MODULE__{errors: errors}) do
    Enum.map_join(errors, "\n", &format_error/1)
  end

  defp format_error(%{"code" => code, "message" => message}) do
    "Kinde Management API #{code} error: #{message}"
  end

  defp format_error(unexpected_error) do
    "Kinde Management API unexpected error: " <> inspect(unexpected_error)
  end
end
