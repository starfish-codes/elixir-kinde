defmodule Kinde.NoAccessTokenError do
  @moduledoc """
  Could be returned by management API server when it didn't manage to obtain
  access token prior to the API call per se
  """

  @type t() :: %__MODULE__{}

  defexception []

  @impl Exception
  def message(%__MODULE__{}) do
    "Kinde Management API couldn't run the request due to lacking of the access token"
  end
end
