# frozen_string_literal: true

module Wallet
  module Api
    module Mempool
      module Transactions
        def broadcast(tx_hex)
          request { |http| http.post("#{@gateway}/tx", body: tx_hex) }
        end
      end
    end
  end
end