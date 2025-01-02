defmodule Kinde.TestClients.InternalServerError do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn
  import Req.Test

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    conn
    |> put_status(:internal_server_error)
    |> text("INTERNAL SERVER ERROR")
  end
end
