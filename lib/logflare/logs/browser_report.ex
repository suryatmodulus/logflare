defmodule Logflare.Logs.BrowserReport do
  require Logger

  def handle_batch(batch) when is_list(batch) do
    Enum.map(batch, fn x -> handle_event(x) end)
  end

  def handle_event(params) when is_map(params) do
    report = handle_json(params)

    %{
      "message" => message(report),
      "metadata" => report
    }
  end

  def message(report) do
    inspect(report)
  end

  def handle_json(json) when is_map(json) do
    for {key, val} <- json,
        into: %{},
        do: {String.replace(key, "-", "_"), handle_json(val)}
  end

  def handle_json(value), do: value
end
