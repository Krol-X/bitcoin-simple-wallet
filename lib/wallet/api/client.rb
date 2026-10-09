# frozen_string_literal: true

require_relative 'core/network'

module Wallet
  module Api
    class Client
      def initialize(network: :mainnet, provider: Api::Mempool)
        Network.validate!(network)
        @provider = provider.new(network: network)
      end

      def get_address(...) = @provider.get_address(...)
    end
  end
end
