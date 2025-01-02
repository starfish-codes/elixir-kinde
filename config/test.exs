import Config

config :joken_jwks, strategy: Kinde.TestJwksStrategy

config :kinde,
  jwks_url: "https://example.com"

config :kinde, Kinde,
  plug: {Req.Test, Kinde},
  retry: false

config :kinde, Kinde.ManagementAPI,
  plug: {Req.Test, Kinde.ManagementAPI},
  retry: false
