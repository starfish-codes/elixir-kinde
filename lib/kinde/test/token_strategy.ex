defmodule Kinde.Test.TokenStrategy do
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
