# frozen_string_literal: true
# docs: https://mempool.space/ru/signet/docs/api/rest

require_relative '../core/http_client'
require_relative 'addresses'

module Wallet
  module Api
    module Mempool
      class Client < HttpClient
        GATEWAYS = {
          mainnet: 'https://mempool.space/api',
          signet: 'https://mempool.space/signet/api',
          testnet4: 'https://mempool.space/testnet4/api'
        }.freeze

        include Addresses

        def initialize(network: :mainnet)
          super()
          @network = network
          @gateway = GATEWAYS.fetch(network)
        end
      end
    end
  end
end
