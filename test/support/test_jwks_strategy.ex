defmodule Kinde.TestJwksStrategy do
  @behaviour JokenJwks.SignerMatchStrategy

  # Generated with `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:512`
  @pem File.read!("test/support/keys/test_jwks.pem")
  @kid "testkid"

  @impl JokenJwks.SignerMatchStrategy
  def match_signer_for_kid(kid, _options), do: {:ok, signer(kid)}

  def sign(claims), do: Joken.Signer.sign(claims, signer(@kid))

  defp signer(kid),
    do: Joken.Signer.create("RS256", %{"pem" => @pem}, %{"kid" => kid})
end
