import Config

config :kinde, Kinde.Token, test_strategy: true

config :kinde, Kinde,
  plug: {Req.Test, Kinde},
  retry: false

config :kinde, Kinde.ManagementAPI,
  plug: {Req.Test, Kinde.ManagementAPI},
  retry: false
