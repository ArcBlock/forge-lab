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

  defmodule Helper do
    @moduledoc """
    Contains helper functions to generate asset address for GiftTx transaction.
    """
    alias Mcrypto.Hasher.Sha3
    alias ForgeAbi.Transaction

    def get_address(tx) do
      tx = %{tx | signatures: []}
      hash = Mcrypto.hash(%Sha3{}, Transaction.encode(tx))
      AbtDid.hash_to_did(:asset, hash, form: :short)
    end
  end

  defmodule Dedup do
    @moduledoc """
    Deduplicates the GiftTx transaction.
    """

    use ForgePipe.Builder
    alias CoreTx.Gift.Helper

    require Logger

    def init(opts), do: opts

    def call(%{tx: tx, db_handler: handler} = info, _opts) do
      address = Helper.get_address(tx)

      case handler.get(address) do
        nil -> info
        _ -> put_status(info, :invalid_tx, :dedup)
      end
    end
  end

  defmodule UpdateTx do
    @moduledoc """
    Updates the global state according to the GiftTx transaction.
    """
    use ForgeAbi.Unit
    use ForgePipe.Builder

    alias CoreState.{Account, Asset}
    alias ForgeAbi.AssetState
    alias CoreTx.Gift.Helper

    def init(opts), do: opts

    def call(%{itx: itx, tx: tx, context: context, db_handler: handler} = info, _opts) do
      %{sender_state: sender_state, receiver_state: receiver_state} = info

      new_sender_state = update_sender_state(sender_state, itx, tx, context, handler)
      new_receiver_state = update_receiver_state(receiver_state, itx, context, handler)
      gen_asset(tx, context, handler)

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

    defp gen_asset(tx, context, handler) do
      attrs = %{
        address: Helper.get_address(tx),
        owner: tx.from,
        readonly: true
      }

      asset = Asset.create(AssetState.new(), attrs, context)
      :ok = handler.put!(asset.address, asset)
    end
  end
end
