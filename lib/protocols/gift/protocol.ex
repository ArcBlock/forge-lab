defmodule CoreTx.Gift do
  defmodule Rpc do
    import ForgeSdk.Tx.Builder, only: [tx: 2]

    tx(:prepare_gift, multisig: true)

    def finalize_gift(tx, opts) do
      wallet = opts[:wallet] || raise "wallet must be provided"
      ForgeSdk.multisig(tx: tx, wallet: wallet)
    end
  end
end
