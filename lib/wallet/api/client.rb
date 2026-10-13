# frozen_string_literal: true

require_relative 'providers/mempool'

module Wallet
  module Api
    class Client
      SUPPORTED_NETWORKS = %i[mainnet signet testnet4].freeze

      def initialize(network: :mainnet, provider: Providers::Mempool)
        validate!(network)
        @provider = provider.new(network: network)
      end

      def_delegators :@provider, :get_address, :get_utxo, # account
                     :get_transaction, :broadcast         # transactions

      private

      def validate!(name)
        return name if SUPPORTED_NETWORKS.include?(name)
        raise ArgumentError, "unknown network: #{name} (supported: #{SUPPORTED_NETWORKS.join(', ')})"
      end
    end
  end
end
