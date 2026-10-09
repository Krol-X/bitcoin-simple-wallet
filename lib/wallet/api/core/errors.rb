# frozen_string_literal: true

module Wallet
  module Api
    class Error < StandardError; end

    class ArgumentError < Error; end

    class TransportError < Error; end

    class ServerError < Error; end

    class InvalidRequest < Error; end

    class NotFound < Error; end
  end
end
