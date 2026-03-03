defmodule Kinde.ReqPligins.AllowOwnership do
  @moduledoc """
  Req plugin to allow onwnership
  """

  @spec attach(Req.Request.t()) :: Req.Request.t()
  def attach(request) do
    request
    |> Req.Request.register_options([:owner])
    |> Req.Request.prepend_request_steps(allow_ownership: &allow_ownership/1)
  end

  defp allow_ownership(request) do
    with {Req.Test, mock} <- Req.Request.get_option(request, :plug),
         owner when is_pid(owner) <- Req.Request.get_option(request, :owner) do
      Req.Test.allow(mock, owner, self())
    end

    request
  end
end
