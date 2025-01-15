defmodule Kinde.Test.Generators do
  @moduledoc false

  @prefix "kp_"
  @id_length_bytes 16
  @first_names [
    "Aaliyah",
    "Aaron",
    "Abagail",
    "Abbey",
    "Abbie",
    "Abbigail",
    "Marcellus",
    "Marcelo",
    "Marcia",
    "Marco",
    "Marcos",
    "Rickie",
    "Ricky",
    "Rico",
    "Rigoberto",
    "Riley"
  ]
  @last_names [
    "Abbott",
    "Abernathy",
    "Abshire",
    "Ada",
    "Botsford",
    "Boyer",
    "Boyle",
    "Bradtke",
    "Brakus",
    "Braun",
    "Breitenberg",
    "Brekke",
    "Crooks",
    "Cruickshank",
    "Cummerata",
    "Cummings",
    "Dach",
    "D'Amore",
    "Daniel"
  ]

  @spec generate_kinde_id() :: String.t()
  def generate_kinde_id do
    @id_length_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
    |> then(fn id -> @prefix <> id end)
  end

  @spec generate_verifier() :: String.t()
  def generate_verifier do
    64
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  @spec generate_user() :: map()
  def generate_user, do: generate_user(generate_kinde_id())

  @spec generate_user(String.t()) :: map()
  def generate_user(id) do
    %{
      id: id,
      first_name: generate_first_name(),
      last_name: generate_last_name(),
      preferred_email: generate_email(),
      provided_id: generate_id(),
      is_suspended: false,
      total_sign_ins: 0,
      failed_sign_ins: 0,
      created_on: DateTime.utc_now()
    }
  end

  @spec generate_users(integer()) :: [map()]
  def generate_users(users_count) when users_count > 0,
    do: Enum.map(1..users_count, fn _index -> generate_user() end)

  def generate_users(_users_count), do: nil

  def generate_first_name, do: Enum.random(@first_names)
  def generate_last_name, do: Enum.random(@last_names)
  def generate_email, do: "#{generate_first_name()}@example.com"

  def generate_id do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)

    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    |> uuid_to_string()
  end

  defp uuid_to_string(<<u0::32, u1::16, u2::16, u3::16, u4::48>>) do
    [
      Base.encode16(<<u0::32>>, case: :lower),
      ?-,
      Base.encode16(<<u1::16>>, case: :lower),
      ?-,
      Base.encode16(<<u2::16>>, case: :lower),
      ?-,
      Base.encode16(<<u3::16>>, case: :lower),
      ?-,
      Base.encode16(<<u4::48>>, case: :lower)
    ]
    |> IO.iodata_to_binary()
  end
end
