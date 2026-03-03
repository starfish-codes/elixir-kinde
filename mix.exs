defmodule Kinde.MixProject do
  use Mix.Project

  def project do
    [
      app: :kinde,
      version: "0.1.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      name: "Kinde",
      source_url: "https://github.com/starfish-codes/elixir-kinde",
      description: "Elixir SDK for Kinde authentication (OIDC + PKCE) and Management API",
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Kinde.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "main"
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/starfish-codes/elixir-kinde"}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5.17"},
      {:joken_jwks, "~> 1.6"},
      {:plug, "~> 1.16", only: [:test]},
      {:faker, "~> 0.18.0", only: [:test]},
      {:excoveralls, "~> 0.18.5", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end
end
