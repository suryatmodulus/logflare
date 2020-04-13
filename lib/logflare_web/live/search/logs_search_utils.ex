defmodule Logflare.Logs.Search.Utils do
  @moduledoc """
  Utilities for Logs search and Logs live view modules
  """
  require Logger

  def format_error(%Tesla.Env{body: body}) do
    body
    |> Poison.decode!()
    |> Map.get("error")
    |> Map.get("message")
  end

  def format_error(e), do: e

  def gen_search_tip() do
    tips = [
      "Search is case sensitive.",
      "Exact match an integer (e.g. `m.response.status_code:500`).",
      "Integers support greater and less than symobols (e.g. `m.response.origin_time:<1000`).",
      ~s|Exact match a string in a field (e.g. `m.response.cf_ray:"505c16f9a752cec8-IAD"`).|,
      "Timestamps support greater and less than symbols (e.g. `t:>=2019-07-01`).",
      ~s|Match a field with regex (e.g. `m.browser:~"Firefox 5\\d"`).|,
      "Search a date range (e.g. `t:2019-07-{01..05}T00:00:00`).",
      "Default behavoir is to search the log message field (e.g. `error`).",
      "Turn off Live Search to search the full history of this source.",
      "Timestamps are automatically converted to UTC if local time is displayed."
    ]

    Enum.random(tips)
  end

  def halt(so, halt_reason) when is_binary(halt_reason) when is_atom(halt_reason) do
    so
    |> put_result(:error, :halted)
    |> put_status(:halted, halt_reason)
  end

  def put_result(so, {:error, err}) do
    %{so | error: err}
  end

  def put_result(so, :error, err) do
    %{so | error: err}
  end

  def put_result(so, key, value) when is_atom(key) do
    %{so | key => value}
  end

  def put_status(so, status) do
    %{so | status: status}
  end

  def put_status(so, key, status) do
    %{so | status: {key, status}}
  end

  def put_result_in(_, so, path \\ nil)
  def put_result_in(:ok, so, _), do: so
  def put_result_in({:ok, value}, so, path) when is_atom(path), do: %{so | path => value}
  def put_result_in({:error, term}, so, _), do: %{so | error: term}
  def put_result_in(value, so, path), do: %{so | path => value}
end
