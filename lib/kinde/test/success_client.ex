defmodule Kinde.Test.SuccessClient do
  @moduledoc false

  @behaviour Plug

  import Kinde.Test.Generators
  import Req.Test
  alias Plug.Conn

  @default_access_token "test-access-token"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{request_path: "/oauth2/token"} = conn, opts) do
    access_token = Keyword.get(opts, :access_token, @default_access_token)
    expires_in = Keyword.get(opts, :expires_in, 86_399)

    claims = %{
      "sub" => generate_kinde_id(),
      "given_name" => generate_first_name(),
      "family_name" => generate_last_name(),
      "email" => generate_email(),
      "picture" => "https://example.com/picture.jpg"
    }

    {:ok, id_token} = Kinde.Test.TokenStrategy.sign(claims)

    json(conn, %{
      access_token: access_token,
      expires_in: expires_in,
      id_token: id_token,
      scope: "openid profile email offline",
      refresh_token: "",
      token_type: "bearer"
    })
  end

  # Get user
  def call(%Conn{request_path: "/api/v1/user", query_params: %{"id" => id}} = conn, _opts),
    do: json(conn, generate_user(id))

  # list users
  def call(%Conn{request_path: "/api/v1/users", query_params: query_params} = conn, opts) do
    next_token = Map.get(query_params, "next_token")
    per_page = Keyword.get(opts, :per_page, 10)
    total = Keyword.get(opts, :total, 42)
    sent = already_sent(next_token)
    to_send = to_send(total, sent, per_page)

    json(conn, %{
      code: "OK",
      message: "Success",
      users: generate_users(to_send),
      next_token: next_token(sent + to_send, total)
    })
  end

  defp already_sent(nil), do: 0

  defp already_sent(next_token) do
    next_token
    |> Base.decode64!()
    |> Jason.decode!()
    |> Map.fetch!("count")
  end

  defp to_send(total, sent, per_page) do
    case total - sent do
      diff when diff < per_page -> diff
      _gt_or_eq_than_per_page -> per_page
    end
  end

  defp next_token(count, total) when count < total do
    %{count: count}
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp next_token(_sent, _total), do: nil
end
