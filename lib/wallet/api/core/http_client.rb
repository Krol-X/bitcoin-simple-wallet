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
        case response
        in { status: 200..299, body: body }
          JSON.parse(body.to_s)
        in { status: 400 }
          raise InvalidRequest, response.to_s
        in { status: 404 }
          raise NotFound, response.to_s
        in { status: 500..599 }
          raise ServerError, response.to_s
        else
          raise TransportError, response.to_s
        end
      end
    end
  end
end

