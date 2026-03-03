defmodule Kinde.ObtainingTokenError do
  @moduledoc """
  Obtaining of the token failed.
  Effectively it means that `/oauth2/token` request was finished with an error
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
