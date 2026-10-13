# frozen_string_literal: true

require 'bitcoin'

module Wallet
  class Account
    attr_reader :key, :client, :network

    # key: Wallet::PrivateKey
    # client: Wallet::Api::Client
    def initialize(key:, client:, network: :mainnet)
      @key = key
      @client = client
      @network = network
      Bitcoin.network = network
    end

    def address
      @address ||= Bitcoin.encode_segwit_address(0, key.value.hash160)
    end

    def address_info
      @address_info ||= client.get_address(address)
    end

    def utxos
      @utxos ||= client.get_utxo(address)
    end

    # Сбрасывает кэш, следующий доступ сходит в сеть заново.
    def refresh!
      @address_info = nil
      @utxos = nil
      self
    end

    def confirmed_balance = address_info.confirmed_balance

    def unconfirmed_balance = address_info.unconfirmed_balance

    def total_balance = address_info.total_balance

    def spendable_utxos
      utxos.select(&:confirmed?)
    end

    # amount в сатоши. Возвращает реальный txid отправленной транзакции.
    def send_funds(to:, amount:)
      tx = Transaction.new(key: key.value, utxos: utxos, to_addr: to, amount: amount)
      client.broadcast(tx.tx_hex)
      tx.txid
    end
  end
end
