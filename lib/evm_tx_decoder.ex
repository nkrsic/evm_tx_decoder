defmodule EvmTxDecoder do
  @moduledoc """
  Documentation for `EvmTxDecoder`.
  """

  @doc """
  Decode a transaction.

  ## Examples

      iex> EvmTxDecoder.decode_tx("0xa4fe82cb29db3f79e3444257ec6e6e84a2b0e6748cd4aa95c1426c7a0ee7c946")
      "Decoding 0xa4fe82cb29db3f79e3444257ec6e6e84a2b0e6748cd4aa95c1426c7a0ee7c946"

  """
  def decode_tx(hash) do
    "Decoding #{hash}"
  end

  def fetch_tx(hash) do
    IO.puts("Fetching #{hash}")

    case Ethers.get_transaction(hash) do
      {:ok, tx} -> {:ok, tx.metadata.block_number}
      {:error, reason} -> {:error, reason}
      response -> {:error, {:unexpected_response, response}}
    end
  end
end
