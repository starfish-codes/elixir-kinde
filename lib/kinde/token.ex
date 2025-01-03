defmodule Kinde.Token do
  @moduledoc false
  use Joken.Config

  if Application.compile_env(:kinde, [__MODULE__, :test_strategy], false) do
    add_hook(JokenJwks, strategy: Kinde.Test.TokenStrategy)
  else
    add_hook(JokenJwks, strategy: Kinde.TokenStrategy)
  end

  @impl Joken.Config
  def token_config, do: default_claims(skip: ~w[aud iss]a)
end
