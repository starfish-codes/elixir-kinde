defmodule Kinde.NoAccessTokenError do
  @moduledoc """
  Returned by `Kinde.ManagementAPI` when an API call is made before the
  access token has been obtained (e.g. right after startup or after a
  renewal failure).
  """

  @type t() :: %__MODULE__{}

  defexception []

  @impl Exception
  def message(%__MODULE__{}) do
    "Kinde Management API couldn't run the request due to lacking of the access token"
  end
end
