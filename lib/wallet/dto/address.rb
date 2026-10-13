# frozen_string_literal: true

module Wallet
  module Dto
    # GET /address/:address — вложенные объекты chain_stats / mempool_stats
    Stats = Data.define(:tx_count, :funded_txo_count, :funded_txo_sum, :spent_txo_count, :spent_txo_sum)

    Address = Data.define(:address, :chain_stats, :mempool_stats) do
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
  end
end
