import Config

config :joken_jwks, strategy: Kinde.TestJwksStrategy

config :joken_jwks, Kinde.TokenStrategy,
  should_start: false,
  strategy: Kinde.TestJwksStrategy,
  jwks_url: "https://starfish-dev.eu.kinde.com/.well-known/jwks",
  log_level: :debug

config :kinde, Kinde,
  plug: {Req.Test, Kinde},
  retry: false

config :kinde, Kinde.ManagementAPI,
  plug: {Req.Test, Kinde.ManagementAPI},
  retry: false
