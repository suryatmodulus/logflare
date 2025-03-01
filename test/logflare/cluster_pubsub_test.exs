defmodule Logflare.ClusterPubSubTest do
  @moduledoc false
  use Logflare.DataCase, async: false

  alias Logflare.Source.ChannelTopics
  alias Logflare.PubSubRates

  defp flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end

  describe "PubSubRates" do
    setup do
      on_exit(&flush_mailbox/0)
      [source: insert(:source, user: insert(:user))]
    end

    test "subscribe/1 inserts", %{source: %{token: source_token}} do
      PubSubRates.subscribe(:inserts)

      TestUtils.retry_assert(fn ->
        PubSubRates.global_broadcast_rate({:inserts, source_token, %{data: "some val"}})
        assert_received {:inserts, ^source_token, %{data: "some val"}}
      end)
    end

    test "subscribe/1 rates", %{source: %{token: source_token}} do
      PubSubRates.subscribe(:rates)

      TestUtils.retry_assert(fn ->
        PubSubRates.global_broadcast_rate({:rates, source_token, %{data: "some val"}})
        assert_received {:rates, ^source_token, %{data: "some val"}}
      end)
    end

    test "subscribe/1 buffers", %{source: %{token: source_token}} do
      PubSubRates.subscribe(:buffers)

      TestUtils.retry_assert(fn ->
        PubSubRates.global_broadcast_rate({:buffers, source_token, %{data: "some val"}})
        assert_received {:buffers, ^source_token, %{data: "some val"}}
      end)
    end
  end

  describe "ChannelTopics" do
    setup do
      [source: insert(:source, user: insert(:user))]
    end

    test "broadcast to dashboard", %{source: %{token: source_token}} do
      ChannelTopics.subscribe_dashboard(source_token)
      ChannelTopics.broadcast_log_count(%{log_count: 1111, source_token: source_token})
      ChannelTopics.broadcast_rates(%{last_rate: 2222, source_token: source_token})
      ChannelTopics.broadcast_buffer(%{buffer: 3333, source_token: source_token})

      :timer.sleep(500)
      assert_received %_{event: "log_count", payload: %{log_count: "1,111"}}
      assert_received %_{event: "rate", payload: %{last_rate: 2222}}
      assert_received %_{event: "buffer", payload: %{buffer: 3333}}
    end

    test "broadcast new source events", %{source: source} do
      ChannelTopics.subscribe_source(source.token)
      le = build(:log_event, source: source)
      ChannelTopics.broadcast_new(le)

      assert_received %_{event: event, payload: %{body: _}}
      assert event =~ "new"
    end
  end
end
