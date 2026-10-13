# frozen_string_literal: true

module Wallet
  module Dto
    Transaction = Data.define(:txid, :version, :locktime, :size, :weight, :fee, :confirmed, :block_height, :block_time) do
      def confirmed?
        confirmed
      end
    end
  end
end
