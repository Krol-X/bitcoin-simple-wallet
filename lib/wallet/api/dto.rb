# frozen_string_literal: true

module Wallet
  module Dto
    Stats = Data.define(:tx_count, :funded_txo_count, :funded_txo_sum, :spent_txo_count, :spent_txo_sum)

    Account = Data.define(:address, :chain_stats, :mempool_stats) do
      def confirmed_balance
        chain_stats.funded_txo_sum - chain_stats.spent_txo_sum
      end

      def unconfirmed_balance
        mempool_stats.funded_txo_sum - mempool_stats.spent_txo_sum
      end

      def total_balance
        confirmed_balance + unconfirmed_balance
      end
    end

    Transaction = Data.define(:txid, :version, :locktime, :size, :weight, :fee, :confirmed, :block_height, :block_time) do
      def confirmed?
        confirmed
      end
    end

    Utxo = Data.define(:txid, :vout, :value, :confirmed, :block_height) do
      def confirmed?
        confirmed
      end
    end
  end
end