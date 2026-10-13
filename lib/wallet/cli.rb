# frozen_string_literal: true

module Wallet
  class CLI
    SATS_PER_BTC = 100_000_000

    attr_reader :account, :out

    def initialize(account:, out: $stdout)
      @account = account
      @out = out
    end

    def run(argv = ARGV)
      command = argv[0]

      case command
      when 'balance', nil
        print_balance
      when 'send'
        send_funds(argv[1], argv[2])
      else
        out.puts 'Неизвестная команда. Используйте: balance | send <addr> <amount>'
      end

      0
    rescue StandardError => e
      out.puts "Ошибка: #{e.message}"
      1
    end

    private

    def print_balance
      out.puts "Адрес: #{account.address}"
      out.puts "Баланс: #{account.total_balance} sats (#{btc(account.total_balance)} sBTC)"
      out.puts "  подтверждено: #{account.confirmed_balance} sats"
      out.puts "  в мемпуле:    #{account.unconfirmed_balance} sats"
    end

    def send_funds(to_addr, amount_btc)
      raise 'Укажите адрес получателя и сумму (например: send tb1q... 0.001)' unless to_addr && amount_btc&.to_f&.positive?

      amount_sats = (amount_btc.to_f * SATS_PER_BTC).to_i

      out.puts 'Формируем транзакцию на ' \
                 "#{amount_sats} sats..."

      txid = account.send_funds(to: to_addr, amount: amount_sats)

      out.puts "Транзакция отправлена! TxID: #{txid}"
    end

    def btc(sats)
      sats.to_f / SATS_PER_BTC
    end
  end
end
