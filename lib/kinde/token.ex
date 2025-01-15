defmodule Kinde.Token do
  @moduledoc false
  def token_config, do: Joken.Config.default_claims(skip: ~w[aud iss]a)

  def verify_and_validate(bearer_token, key \\ :default_signer, context \\ nil) do
    config = Application.get_env(:kinde, Kinde.Token, %{test_strategy: false})

    strategy =
      if config[:test_strategy],
        do: Kinde.Test.TokenStrategy,
        else: Kinde.TokenStrategy

    Joken.verify_and_validate(
      token_config(),
      bearer_token,
      Joken.Signer.parse_config(key),
      context,
      [
        {JokenJwks, strategy: strategy}
      ]
    )
  end
end
