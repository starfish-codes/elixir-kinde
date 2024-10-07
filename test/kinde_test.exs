defmodule KindeTest do
  use ExUnit.Case
  doctest Kinde

  test "greets the world" do
    assert Kinde.hello() == :world
  end
end
