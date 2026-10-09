# frozen_string_literal: true

require 'stringio'
require 'bitcoin'

require_relative 'lib/bitcoin/signet'
require_relative 'lib/bitcoin/openssl3'

require_relative 'lib/wallet/private_key'
require_relative 'lib/wallet/api/client'

class App
  def self.main
    Bitcoin.network = :signet

    key = Wallet::PrivateKey.new

    client = Wallet::Api::Client.new(network: :signet)
    p client.get_address(key.to_address)
  end
end

App.main
