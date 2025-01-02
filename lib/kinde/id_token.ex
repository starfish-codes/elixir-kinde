defmodule Kinde.IdToken do
  @moduledoc false
  use Joken.Config

  @strategy Application.compile_env(:joken_jwks, :strategy, Kinde.TokenStrategy)

  add_hook(JokenJwks, strategy: @strategy)

  @impl Joken.Config
  def token_config, do: default_claims(skip: ~w[aud iss]a)
end
