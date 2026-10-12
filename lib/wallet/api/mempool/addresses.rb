# frozen_string_literal: true

module Wallet
  module Api
    module Mempool
      module Addresses
        def get_address(addr)
          request { |http| http.get "#{@gateway}/address/#{addr}" }
        end

        def get_utxo(addr)
          request { |http| http.get "#{@gateway}/address/#{addr}/utxo" }
        end
      end
    end
  end
end