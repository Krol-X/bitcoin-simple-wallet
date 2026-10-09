# frozen_string_literal: true

require 'stringio'
require 'bitcoin'

require_relative 'lib/bitcoin/signet'
require_relative 'lib/bitcoin/openssl3'

require_relative 'lib/wallet/private_key'

class App
  def self.main
    Bitcoin.network = :signet

    key = PrivateKey.new
    print "#{key.value}"
  end
end

App.main
