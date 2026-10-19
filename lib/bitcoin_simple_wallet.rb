# frozen_string_literal: true

require "zeitwerk"
require_relative "bitcoin_simple_wallet/version"

loader = Zeitwerk::Loader.for_gem
loader.setup

module BitcoinSimpleWallet
  class Error < StandardError; end
end
