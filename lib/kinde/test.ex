defmodule Kinde.Test do
  @moduledoc """
  defmodule MyAppWeb.AuthControllerTest do
    use MyAppWeb.ConnCase
    use Kinde.Test

    setup :stub_with_success
  end
  """

  defmacro __using__(opts) do
    # stub_with_success = :proplists.get_bool(:stub_with_success, opts)
    quote do
      import unquote(__MODULE__)
    end
  end

  def stub_with_success() do
    Req.Test.stub(Kinde, Kinde.Test.SuccessClient)
  end
end
