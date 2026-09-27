defmodule EvmTxDecoder.Poller do
  use GenServer
  require Logger

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    send(self(), :poll)
    {:ok, %{interval_ms: Keyword.fetch!(opts, :interval_ms)}}
  end

  @impl true
  def handle_info(:poll, state) do
    case poll_chain() do
      {:ok, block_number} -> Logger.info("Fetched transaction from block #{block_number}")
      {:error, reason} -> Logger.warning("Blockchain poll failed: #{inspect(reason)}")
    end

    Process.send_after(self(), :poll, state.interval_ms)
    {:noreply, state}
  end

  defp poll_chain do
    EvmTxDecoder.fetch_tx("0xa3214679919f840716f8443b58f9f09f29684c12960485b49a61ed19b481f74c")
  end
end
