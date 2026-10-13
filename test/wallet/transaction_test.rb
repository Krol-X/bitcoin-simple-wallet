# frozen_string_literal: true

# Тесты: lib/wallet/transaction.rb (криптография настоящая, сеть не нужна)
require_relative 'support'

def build_tx(total_values:, amount:, confirmed: true)
  key = make_key
  dest = key_address(make_key)
  utxos = total_values.map { |v| make_utxo(value: v, confirmed: confirmed) }
  tx = Wallet::Transaction.new(key: key, utxos: utxos, to_addr: dest, amount: amount)
  [tx, key, dest]
end

check 'сборка со сдачей: 2 выхода, фикс. комиссия' do
  tx, _key, _dest = build_tx(total_values: [100_000], amount: 50_000)
  assert_equal 1000, tx.fee
  parsed = Bitcoin::Protocol::Tx.new(tx.tx_hex.htb)
  assert_equal 2, parsed.ver
  assert_equal 1, parsed.in.size
  assert_equal [50_000, 49_000], parsed.out.map(&:value)
end

check 'txid совпадает с пересчётом из hex' do
  tx, = build_tx(total_values: [100_000], amount: 50_000)
  assert_equal txid_of_hex(tx.tx_hex), tx.txid
  assert_match(/\A[0-9a-f]{64}\z/, tx.txid)
end

check 'несколько входов суммируются' do
  tx, = build_tx(total_values: [60_000, 60_000], amount: 100_000)
  parsed = Bitcoin::Protocol::Tx.new(tx.tx_hex.htb)
  assert_equal 2, parsed.in.size
  assert_equal [100_000, 19_000], parsed.out.map(&:value)
end

check 'сдача ровно DUST_LIMIT (294) — выход создаётся' do
  tx, = build_tx(total_values: [100_000], amount: 98_706)
  parsed = Bitcoin::Protocol::Tx.new(tx.tx_hex.htb)
  assert_equal [98_706, 294], parsed.out.map(&:value)
end

check 'сдача 293 (< DUST_LIMIT) — выхода нет, уходит майнеру' do
  tx, = build_tx(total_values: [100_000], amount: 98_707)
  parsed = Bitcoin::Protocol::Tx.new(tx.tx_hex.htb)
  assert_equal [98_707], parsed.out.map(&:value)
end

check 'нехватка средств — ошибка отправки' do
  assert_raises(RuntimeError, 'Недостаточно средств для отправки') do
    build_tx(total_values: [50_000], amount: 60_000)
  end
end

check 'не хватает на комиссию — ошибка комиссии' do
  assert_raises(RuntimeError, 'Недостаточно средств для покрытия комиссии') do
    build_tx(total_values: [100_000], amount: 99_500)
  end
end

check 'неподтверждённые UTXO игнорируются' do
  assert_raises(RuntimeError, 'Недостаточно средств для отправки') do
    build_tx(total_values: [100_000], amount: 50_000, confirmed: false)
  end
end

check 'смесь: подтверждённые тратятся, неподтверждённые — нет' do
  key = make_key
  dest = key_address(make_key)
  utxos = [make_utxo(value: 60_000, confirmed: true), make_utxo(value: 60_000, confirmed: false)]
  tx = Wallet::Transaction.new(key: key, utxos: utxos, to_addr: dest, amount: 50_000)
  parsed = Bitcoin::Protocol::Tx.new(tx.tx_hex.htb)
  assert_equal 1, parsed.in.size
  assert_equal [50_000, 9_000], parsed.out.map(&:value)
end
