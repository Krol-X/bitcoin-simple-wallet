# frozen_string_literal: true

require_relative 'presenter'
require_relative 'actions'

module Wallet
  module UI
    class CLI
      include Actions

      attr_reader :account, :presenter, :out

      def initialize(account:, presenter: Presenter.new, out: $stdout)
        @account = account
        @presenter = presenter
        @out = out
      end

      def run(arguments)
        case arguments.action
        when :account
          show_balance
        when :send
          send_funds(arguments.address, arguments.amount)
        else
          out.puts presenter.unknown_command
        end
      rescue StandardError => e
        out.puts presenter.error(e.message)
      end
    end
  end
end
