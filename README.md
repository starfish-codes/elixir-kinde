# Kinde

Elixir SDK for [Kinde](https://kinde.com) authentication.

Implements OpenID Connect with PKCE for secure user authentication and provides a client for the [Kinde Management API](https://docs.kinde.com/kinde-apis/management/).

## Installation

Add `kinde` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kinde, "~> 0.1.0"}
  ]
end
```

## Configuration

```elixir
# config/runtime.exs
config :kinde,
  domain: "https://yourapp.kinde.com",
  client_id: "your_client_id",
  client_secret: "your_client_secret",
  redirect_uri: "http://localhost:4000/callback"
```

### All configuration keys

#### Authentication (OIDC + PKCE)

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `:domain` | yes | — | Kinde domain (e.g. `"https://yourapp.kinde.com"`) |
| `:client_id` | yes | — | OAuth2 client ID |
| `:client_secret` | yes | — | OAuth2 client secret |
| `:redirect_uri` | yes | — | Callback URL after authentication |
| `:prompt` | no | `"login"` | OAuth2 prompt parameter (`"login"`, `"create"`, `"none"`) |
| `:scopes` | no | `["openid", "profile", "email", "offline"]` | OAuth2 scopes |

These keys can also be passed directly to `Kinde.auth/2` and `Kinde.token/4` as a map, which takes precedence over app config.

#### Management API

Configured under the `:management_api` key:

```elixir
config :kinde, :management_api,
  client_id: "management_client_id",
  client_secret: "management_client_secret",
  business_domain: "https://yourapp.kinde.com",
  req_opts: []
```

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `:client_id` | yes | — | Management API client ID |
| `:client_secret` | yes | — | Management API client secret |
| `:business_domain` | no | value of `:domain` | API base URL (falls back to top-level `:domain`) |
| `:req_opts` | no | `[]` | Extra options passed to `Req.new/1` (e.g. custom plugins, adapters) |

If required keys are missing, the Management API server is not started (returns `:ignore`), and the rest of the application boots normally.

#### State management

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `:state_management_impl` | no | `Kinde.StateManagementAgent` | Module implementing `Kinde.StateManagement` behaviour |

#### Testing

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `:test_strategy` | no | `false` | When `true`, uses `Kinde.Test.TokenStrategy` instead of JWKS verification (compile-time) |

## Usage

### Authentication (OIDC + PKCE)

**1. Generate the authorization URL**

```elixir
# Using app config
{:ok, authorize_url} = Kinde.auth()

# With extra params (will be returned after token exchange)
{:ok, authorize_url} = Kinde.auth(%{}, %{return_to: "/dashboard"})

# With explicit config (overrides app env)
{:ok, authorize_url} = Kinde.auth(%{
  domain: "https://yourapp.kinde.com",
  client_id: "...",
  client_secret: "...",
  redirect_uri: "http://localhost:4000/callback"
})
```

Redirect the user to `authorize_url`. Kinde will redirect back to your `redirect_uri` with `code` and `state` query parameters.

**2. Exchange the code for user data**

```elixir
{:ok, user_params, extra_params} = Kinde.token(code, state)

# user_params:
# %{
#   id: "kp_abc123...",
#   given_name: "Jane",
#   family_name: "Doe",
#   email: "jane@example.com",
#   picture: "https://..."
# }

# extra_params — the map passed to Kinde.auth/2
# %{return_to: "/dashboard"}
```

### Management API

The Management API client starts automatically with the application and maintains its own access token via client credentials flow.

```elixir
{:ok, user} = Kinde.ManagementAPI.get_user("kp_abc123")

{:ok, users} = Kinde.ManagementAPI.list_users()
# Handles pagination automatically, returns a flat list
```

## State management

OAuth state and PKCE code verifiers are stored in-memory via `Kinde.StateManagementAgent` (an `Agent`). This works for single-node deployments.

For multi-node setups, implement the `Kinde.StateManagement` behaviour and configure it:

```elixir
config :kinde, :state_management_impl, MyApp.EctoStateManagement
```

See `Kinde.StateManagement` module documentation for a full Ecto-based example.

`take_state/1` must read and delete the entry (one-time use).

## Testing

The library ships with `Kinde.Test.TokenStrategy` that signs tokens with a local RSA key instead of verifying against Kinde's JWKS endpoint. Enable it in your test config:

```elixir
# config/test.exs
config :kinde, test_strategy: true
```

Use `Req.Test` to stub HTTP requests in tests. See `test/kinde_test.exs` for examples.

## License

See [LICENSE](LICENSE) for details.
