# frozen_string_literal: true

module Wallet
  module UI
    class Presenter
      SATS_PER_BTC = 100_000_000

      MENU = [
        '1. Показать баланс',
        '2. Отправить',
        '3. Выход'
      ].freeze

      def balance_lines(account)
        [
          "Адрес: #{account.address}",
          "Баланс: #{account.total_balance} sats (#{btc(account.total_balance)} sBTC)",
          "  подтверждено: #{account.confirmed_balance} sats",
          "  в мемпуле:    #{account.unconfirmed_balance} sats"
        ]
      end

      def sending(amount_sats)
        "Формируем транзакцию на #{amount_sats} sats..."
      end

      def sent(txid)
        "Транзакция отправлена! TxID: #{txid}"
      end

      def invalid_amount
        'Укажите адрес получателя и сумму (например: -s tb1q... 0.001)'
      end

      def unknown_command
        'Неизвестная команда. -a — баланс, -s <addr> <amount> — отправка, без аргументов — REPL.'
      end

      def menu
        MENU
      end

      def prompt(question)
        "#{question}: "
      end

      def error(message)
        "Ошибка: #{message}"
      end

      def to_sats(amount_btc)
        (amount_btc.to_f * SATS_PER_BTC).to_i
      end

      def btc(sats)
        sats.to_f / SATS_PER_BTC
      end
    end
  end
end
