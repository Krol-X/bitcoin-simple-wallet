# frozen_string_literal: true

require_relative 'mappers'

module Wallet
  module Api
    module Mempool
      module Transactions
        def get_tx(txid)
          Mappers.transaction(request { |http| http.get "#{@gateway}/tx/#{txid}" })
        end

        def broadcast(tx_hex)
          request_raw { |http| http.post("#{@gateway}/tx", body: tx_hex) }
        end
      end
    end
  end
end