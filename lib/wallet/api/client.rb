# frozen_string_literal: true

require_relative 'core/network'
require_relative 'mempool/client'

module Wallet
  module Api
    class Client
      def initialize(network: :mainnet, provider: Api::Mempool::Client)
        Network.validate!(network)
        @provider = provider.new(network: network)
      end

      def get_address(...) = @provider.get_address(...)

      def get_utxo(...) = @provider.get_utxo(...)

      def get_tx(...) = @provider.get_tx(...)

      def broadcast(...) = @provider.broadcast(...)
    end
  end
end
