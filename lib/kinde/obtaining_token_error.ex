defmodule Kinde.ObtainingTokenError do
  @moduledoc """
  Returned when the `/oauth2/token` request fails.

  Contains the HTTP `status` code and the response `body` (either a parsed
  map with `"error"` / `"error_description"` keys, or a raw binary).
  """

  @type t() :: %__MODULE__{
          status: Mint.Types.status(),
          body: map() | binary()
        }

  defexception [:status, :body]

  @impl Exception
  def message(%__MODULE__{body: %{"error" => error, "error_description" => description}}) do
    "Kinde error #{error}: #{description}"
  end

  def message(%__MODULE__{status: status, body: body}) do
    "Failed to obtain OAuth2 token with the status #{status}: " <> inspect(body)
  end
end
