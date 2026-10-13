# frozen_string_literal: true

require 'stringio'
require 'bitcoin'

require_relative 'lib/bitcoin/signet'
require_relative 'lib/bitcoin/openssl3'

require_relative 'lib/wallet/private_key'
require_relative 'lib/wallet/api/client'
require_relative 'lib/wallet/transaction'

class App
  def self.main
    Bitcoin.network = :signet

    key = Wallet::PrivateKey.new
    address = Bitcoin.encode_segwit_address(0, key.value.hash160) # Используем нативный SegWit
    client = Wallet::Api::Client.new(network: :signet)

    case ARGV[0]
    when 'balance', nil
      utxos = client.get_utxo(address)
      balance = utxos.map(&:value).sum
      address_info = client.get_address(address)
      puts "Адрес: #{address}"
      puts "Баланс: #{balance} sats (#{balance.to_f / 100_000_000} sBTC)"
      puts "  подтверждено: #{address_info.confirmed_balance} sats"
      puts "  в мемпуле:    #{address_info.unconfirmed_balance} sats"

    when 'send'
      to_addr = ARGV[1]
      amount_btc = ARGV[2].to_f

      raise "Укажите адрес получателя и сумму (например: send tb1q... 0.001)" unless to_addr && amount_btc > 0

      amount_sats = (amount_btc * 100_000_000).to_i

      puts "Получаем UTXO..."
      utxos = client.get_utxo(address)

      puts "Формируем транзакцию на #{amount_sats} sats..."
      tx = Wallet::Transaction.new(key: key.value, utxos: utxos, to_addr: to_addr, amount: amount_sats)

      puts "Отправляем в Mempool..."
      result = client.broadcast(tx.tx_hex)

      puts "Транзакция отправлена! TxID: #{result} (#{tx.txid})"

    else
      puts "Неизвестная команда. Используйте: balance | send <addr> <amount>"
    end
  rescue StandardError => e
    puts "Ошибка: #{e.message}"
  end
end

App.main
