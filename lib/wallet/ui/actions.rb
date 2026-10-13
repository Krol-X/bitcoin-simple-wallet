# frozen_string_literal: true

module Wallet
  module UI
    module Actions
      def show_balance
        out.puts presenter.balance_lines(account)
      end

      def send_funds(to_addr, amount_btc)
        raise presenter.invalid_amount unless to_addr && amount_btc&.to_f&.positive?

        amount_sats = presenter.to_sats(amount_btc)

        out.puts presenter.sending(amount_sats)
        txid = account.send_funds(to: to_addr, amount: amount_sats)

        out.puts presenter.sent(txid)
      end
    end
  end
end
