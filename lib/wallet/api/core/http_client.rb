# frozen_string_literal: true

require 'http'
require 'json'

require_relative 'errors'

module Wallet
  module Api
    class HttpClient
      DEFAULT_TIMEOUT = 10

      attr_reader :timeout

      def initialize(timeout: DEFAULT_TIMEOUT)
        @timeout = timeout
      end

      private

      def request
        http = HTTP.timeout(connect: @timeout, read: @timeout)
        response = yield(http)
        case response.status.code
        in 200..299
          JSON.parse(response.body.to_s)
        in 400
          raise InvalidRequest, response.to_s
        in 404
          raise NotFound, response.to_s
        in 500..599
          raise ServerError, response.to_s
        else
          raise TransportError, response.to_s
        end
      end
    end
  end
end

