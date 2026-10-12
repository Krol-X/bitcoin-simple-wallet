# frozen_string_literal: true

require 'bitcoin'

module Wallet
  class Transaction
    include Bitcoin::Builder

    DUST_LIMIT = 294 # sats для SegWit
    BASE_FEE = 1000 # 0.00001 BTC = 1000 sats (для базового задания)

    attr_reader :tx, :tx_hex, :txid, :fee

    # key: Bitcoin::Key объект
    # utxos: массив UTXO от Mempool API
    # to_addr: строка адреса получателя
    # amount: сумма в сатоши
    def initialize(key:, utxos:, to_addr:, amount:)
      @key = key
      @utxos = utxos
      @to_addr = to_addr
      @amount = amount
      @fee = BASE_FEE # Пока фикс, для бонуса тут будет расчет vbyte

      build_and_sign!
    end

    private

    def build_and_sign!
      # 1. Фильтруем UTXO (берем только подтвержденные)
      confirmed_utxos = @utxos.select { |u| u.dig('status', 'confirmed') }

      # 2. Набираем входы (пока просто берем все, как советует подсказка)
      total_input = confirmed_utxos.sum { |u| u['value'] }

      raise "Недостаточно средств для отправки" if total_input < @amount

      change_amount = total_input - @amount - @fee
      if change_amount < 0
        raise "Недостаточно средств для покрытия комиссии"
      elsif change_amount < DUST_LIMIT
        # Сдача меньше Dust Limit — не создаем выход, копейки уходят майнеру
        change_amount = 0
      end

      # 3. Билдер сам строит транзакцию, подписывает входы и проверяет подписи
      @tx = build_tx do |t|
        t.version 2

        confirmed_utxos.each do |utxo|
          t.input do |i|
            i.prev_out(utxo['txid'], utxo['vout'])
            i.prev_out_script(my_script_pubkey)
            i.prev_out_value(utxo['value'])
            i.signature_key(@key)
          end
        end

        t.output do |o|
          o.value(@amount)
          o.script { |s| s.recipient(@to_addr) }
        end

        if change_amount > 0
          t.output do |o|
            o.value(change_amount)
            o.script { |s| s.recipient(my_address) }
          end
        end
      end

      # 4. Сериализуем в HEX для отправки в Mempool
      @tx_hex = @tx.to_payload.bth
      @txid = real_txid(@tx)
    end

    def my_address
      Bitcoin.encode_segwit_address(0, @key.hash160)
    end

    def my_script_pubkey
      Bitcoin::Script.to_witness_hash160_script(@key.hash160)
    end

    # После сборки builder кладет в tx.hash хеш witness-сериализации (по сути
    # wtxid), а НЕ txid. Настоящий txid — это sha256d от «старого» формата
    # без witness (см. examples/02_build_spend.rb).
    def real_txid(tx)
      tx.refresh_hash
      tx.instance_variable_set(:@binary_hash, nil)
      tx.hash
    end
  end
end