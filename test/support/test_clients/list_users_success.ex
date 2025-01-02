defmodule Kinde.TestClients.ListUsersSuccess do
  @moduledoc false

  @behaviour Plug

  import Kinde.TestHelpers
  import Req.Test

  alias Kinde.TestClients.RenewTokenSuccess
  alias Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{request_path: "/oauth2/token"} = conn, opts),
    do: RenewTokenSuccess.call(conn, opts)

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

  defp generate_users(users_count) when users_count > 0,
    do: Enum.map(1..users_count, fn _index -> generate_user() end)

  defp generate_users(_users_count), do: nil

  defp next_token(count, total) when count < total do
    %{count: count}
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp next_token(_sent, _total), do: nil
end
