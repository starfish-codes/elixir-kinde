import Config

config :kinde, Kinde.Token, test_strategy: true

config :kinde, Kinde, test?: true

config :kinde,
  domain: "https://test.com",
  redirect_uri: "http://localhost:4000/callback",
  client_id: "kinde_client_id",
  client_secret: "kinde_secret",
  test?: true
