defmodule Kinde.Test.TokenStrategy do
  @moduledoc """
  Test token strategy that signs JWTs with a local RSA key from `priv/keys/key.pem`.

  Activated by setting `config :kinde, test_strategy: true` (typically in `config/test.exs`).
  Bypasses JWKS endpoint verification so tests can run without network access.

  Use `sign/1` to generate valid test tokens:

      claims = %{"sub" => "kp_abc123", "email" => "test@example.com"}
      {:ok, token} = Kinde.Test.TokenStrategy.sign(claims)
  """

  @behaviour JokenJwks.SignerMatchStrategy

  @kid "testkid"

  @impl JokenJwks.SignerMatchStrategy
  def match_signer_for_kid(kid, _options), do: {:ok, signer(kid)}

  def sign(claims), do: Joken.Signer.sign(claims, signer(@kid))

  defp signer(kid), do: Joken.Signer.create("RS256", %{"pem" => pem()}, %{"kid" => kid})

  defp pem do
    :kinde
    |> :code.priv_dir()
    |> Path.join("keys/key.pem")
    |> File.read!()
  end
end
