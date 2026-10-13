# frozen_string_literal: true

require_relative 'lib/wallet'
require_relative 'lib/wallet/ui/arguments'
require_relative 'lib/wallet/ui/cli'
require_relative 'lib/wallet/ui/repl'

network = :signet

key = Wallet::PrivateKey.new
client = Wallet::Api::Client.new(network: network)
account = Wallet::Account.new(key: key, client: client, network: network)

arguments = Wallet::UI::Arguments.parse(ARGV)

if arguments.repl?
  exit Wallet::UI::REPL.new(account: account).run
else
  exit Wallet::UI::CLI.new(account: account).run(arguments)
end
