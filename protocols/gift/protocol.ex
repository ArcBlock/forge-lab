defmodule CoreTx.Gift do
  defmodule Rpc do
    @moduledoc """
    Contains helper methods to assemble and sign a GiftTx transaction.
    """

    import ForgeSdk.Tx.Builder, only: [tx: 2]

    tx(:prepare_gift, multisig: true)

    def finalize_gift(tx, opts) do
      wallet = opts[:wallet] || raise "wallet must be provided"
      ForgeSdk.multisig(tx: tx, wallet: wallet)
    end
  end

  defmodule UpdateTx do
    @moduledoc """
    Updates the global state according to the GiftTx transaction.
    """
    use ForgeAbi.Unit
    use ForgePipe.Builder

    alias CoreState.Account

    def init(opts), do: opts

    def call(%{itx: itx, tx: tx, context: context, db_handler: handler} = info, _opts) do
      %{sender_state: sender_state, receiver_state: receiver_state} = info

      new_sender_state = update_sender_state(sender_state, itx, tx, context, handler)
      new_receiver_state = update_receiver_state(receiver_state, itx, context, handler)

      info
      |> put(:sender_state, new_sender_state)
      |> put(:receiver_state, new_receiver_state)
      |> put_status(:ok)
    end

    defp update_sender_state(sender_state, itx, tx, context, handler) do
      new_sender_state =
        Account.update(
          sender_state,
          %{
            nonce: tx.nonce,
            balance: sender_state.balance - itx.value
          },
          context
        )

      :ok = handler.put!(sender_state.address, new_sender_state)

      new_sender_state
    end

    defp update_receiver_state(receiver_state, itx, context, handler) do
      new_receiver_state =
        Account.update(
          receiver_state,
          %{
            balance: receiver_state.balance + itx.value
          },
          context
        )

      :ok = handler.put!(receiver_state.address, new_receiver_state)

      new_receiver_state
    end
  end
end
