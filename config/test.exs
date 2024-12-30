import Config

config :joken_jwks, strategy: Kinde.TestJwksStrategy

config :joken_jwks, Kinde.TokenStrategy,
  should_start: false,
  strategy: Kinde.TestJwksStrategy,
  jwks_url: "https://starfish-dev.eu.kinde.com/.well-known/jwks",
  log_level: :debug

config :kinde,
  req_options: [
    plug: {Req.Test, Kinde}
  ]