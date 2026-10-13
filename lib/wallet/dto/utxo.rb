# frozen_string_literal: true

module Wallet
  module Dto
    # GET /address/:address/utxo
    Utxo = Data.define(:txid, :vout, :value, :confirmed, :block_height) do
      def confirmed?
        confirmed
      end
    end
  end
end
