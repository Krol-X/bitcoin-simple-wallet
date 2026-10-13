# frozen_string_literal: true

require 'optparse'

module Wallet
  module UI
    class Arguments
      attr_reader :action, :address, :amount

      def self.parse(argv) = new(argv)

      def initialize(argv)
        @action = :repl

        parser = build_parser
        rest = parser.parse(argv)
        @address, @amount = rest if @action == :send
      rescue OptionParser::ParseError => e
        warn e.message
        warn parser
        exit 2
      end

      def repl? = @action == :repl

      private

      def build_parser
        OptionParser.new do |o|
          o.banner = 'Usage: bin/cli [-a | -s ADDRESS AMOUNT]'

          o.on('-a', '--account', 'Показать адрес и баланс') { @action = :account }
          o.on('-s', '--send', 'Отправить <address> <amount> BTC') { @action = :send }
          o.on('-h', '--help', 'Помощь') do
            puts o
            exit
          end
        end
      end
    end
  end
end
