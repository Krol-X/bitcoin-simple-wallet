# frozen_string_literal: true

require_relative 'presenter'
require_relative 'actions'

module Wallet
  module UI
    class REPL
      include Actions

      attr_reader :account, :presenter, :out, :input

      def initialize(account:, presenter: Presenter.new, out: $stdout, input: $stdin)
        @account = account
        @presenter = presenter
        @out = out
        @input = input
      end

      def run
        loop do
          print_menu

          case ask('Выберите пункт')
          when '1' then show_balance
          when '2' then run_send
          when '3', 'exit', 'quit', nil then break
          else out.puts presenter.unknown_command
          end
        end

        0
      rescue StandardError => e
        out.puts presenter.error(e.message)
        1
      end

      private

      def print_menu
        out.puts
        out.puts presenter.menu
      end

      def run_send
        send_funds(ask('Адрес получателя'), ask('Сумма в BTC'))
      end

      def ask(question)
        out.print presenter.prompt(question)
        input.gets&.chomp
      end
    end
  end
end
