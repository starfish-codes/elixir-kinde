defmodule Kinde.URL do
  @moduledoc """
    Parsing function that helps to make a fully qualified url. Using elixir's URI module.
  """

  @spec parse(String.t() | URI.t()) :: URI.t()
  def parse(url) when is_binary(url), do: parse(URI.parse(url))
  def parse(url = %URI{scheme: nil}), do: parse("https://#{to_string(url)}")
  def parse(url = %URI{path: nil}), do: parse("#{to_string(url)}/")
  def parse(url), do: url

  @spec parse_to_string(URI.t() | String.t()) :: String.t()
  def parse_to_string(url), do: url |> parse() |> to_string()
end
