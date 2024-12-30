defmodule Kinde.MixProject do
  use Mix.Project

  def project do
    [
      app: :kinde,
      version: "0.1.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
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

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.12"},
      {:finch, "~> 0.19.0"},
      {:joken_jwks, "~> 1.6"},
      {:req, "~> 0.5.8"},
      {:plug, "~> 1.16", only: [:test]},
      {:faker, "~> 0.18.0", only: [:test]}
    ]
  end
end
