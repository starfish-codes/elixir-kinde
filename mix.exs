defmodule Kinde.MixProject do
  use Mix.Project

  def project do
    [
      app: :kinde,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Kinde.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.12"},
      {:finch, "~> 0.19.0"},
      {:joken_jwks, "~> 1.6"},
      {:req, "~> 0.5.8"}
    ]
  end
end
