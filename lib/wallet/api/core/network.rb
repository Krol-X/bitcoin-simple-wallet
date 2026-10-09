# frozen_string_literal: true

module Wallet
  module Api
    class Network
      SUPPORTED = %i[mainnet signet testnet4].freeze

      def self.validate!(name)
        return name if SUPPORTED.include?(name)
        raise ArgumentError, "unknown network: #{name} (supported: #{SUPPORTED.join(', ')})"
      end
    end
  end
end
