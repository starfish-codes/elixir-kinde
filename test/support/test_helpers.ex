defmodule Kinde.TestHelpers do
  @moduledoc false

  @prefix "kp_"
  @id_length_bytes 16

  def generate_kinde_id do
    @id_length_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
    |> then(fn id -> @prefix <> id end)
  end

  def generate_verifier do
    64
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  def generate_user, do: generate_user(generate_kinde_id())

  def generate_user(id) do
    %{
      id: id,
      first_name: Faker.Person.first_name(),
      last_name: Faker.Person.last_name(),
      preferred_email: Faker.Internet.email(),
      provided_id: Faker.UUID.v4(),
      is_suspended: false,
      total_sign_ins: 0,
      failed_sign_ins: 0,
      created_on: Faker.DateTime.backward(100)
    }
  end
end
