# frozen_string_literal: true

require_relative 'mappers'

module Wallet
  module Api
    module Providers
      module Mempool
        module Account
          def get_address(addr)
            Mappers.address(request { |http| http.get "#{@gateway}/address/#{addr}" })
          end

          def get_utxo(addr)
            request { |http| http.get "#{@gateway}/address/#{addr}/utxo" }.map { |u| Mappers.utxo(u) }
          end
        end
      end
    end
  end
end