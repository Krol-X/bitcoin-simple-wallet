# frozen_string_literal: true

# Тесты DTO: lib/wallet/dto/*.rb
require_relative 'support'

check 'Stats хранит поля' do
  s = make_stats(funded: 150_000, spent: 50_000, txs: 3)
  assert_equal 3, s.tx_count
  assert_equal 150_000, s.funded_txo_sum
  assert_equal 50_000, s.spent_txo_sum
end

check 'Address.confirmed_balance = funded - spent (chain)' do
  a = make_address('tb1qtest', chain_funded: 150_000, chain_spent: 50_000)
  assert_equal 100_000, a.confirmed_balance
end

check 'Address.unconfirmed_balance = funded - spent (mempool)' do
  a = make_address('tb1qtest', mem_funded: 20_000, mem_spent: 5_000)
  assert_equal 15_000, a.unconfirmed_balance
end

check 'Address.total_balance = confirmed + unconfirmed' do
  a = make_address('tb1qtest', chain_funded: 100_000, chain_spent: 0, mem_funded: 7_000, mem_spent: 0)
  assert_equal 107_000, a.total_balance
end

check 'Address с нулями даёт нулевые балансы' do
  a = make_address('tb1qtest')
  assert_equal 0, a.confirmed_balance
  assert_equal 0, a.unconfirmed_balance
  assert_equal 0, a.total_balance
end

check 'Utxo#confirmed? отражает флаг' do
  assert_equal true, make_utxo(value: 1).confirmed?
  assert_equal false, make_utxo(value: 1, confirmed: false).confirmed?
end

check 'Utxo хранит txid/vout/value/высоту' do
  u = make_utxo(value: 75_000, vout: 2, txid: 'cd' * 32, block_height: 800_001)
  assert_equal 'cd' * 32, u.txid
  assert_equal 2, u.vout
  assert_equal 75_000, u.value
  assert_equal 800_001, u.block_height
end

check 'Transaction#confirmed? отражает флаг' do
  base = { txid: 'ab' * 32, version: 2, locktime: 0, size: 222, weight: 561,
           fee: 1000, block_height: 1, block_time: 1 }
  assert_equal true, Wallet::Dto::Transactions.new(**base, confirmed: true).confirmed?
  assert_equal false, Wallet::Dto::Transactions.new(**base, confirmed: false).confirmed?
end
