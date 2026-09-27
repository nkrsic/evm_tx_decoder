defmodule EvmTxDecoder.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {EvmTxDecoder.Poller,
       interval_ms: Application.fetch_env!(:evm_tx_decoder, :poll_interval_ms)}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: EvmTxDecoder.Supervisor)
  end
end
