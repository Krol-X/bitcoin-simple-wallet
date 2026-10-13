# frozen_string_literal: true

require_relative 'lib/wallet'
require_relative 'lib/wallet/cli'

network = :signet

key = Wallet::PrivateKey.new
client = Wallet::Api::Client.new(network: network)
account = Wallet::Account.new(key: key, client: client, network: network)

exit Wallet::CLI.new(account: account).run(ARGV)
