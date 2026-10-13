# frozen_string_literal: true

# Тесты мапперов: lib/wallet/api/mempool/mappers.rb
require_relative 'support'

ADDRESS_JSON = {
  'address' => 'tb1qexample',
  'chain_stats' => { 'tx_count' => 2, 'funded_txo_count' => 2, 'funded_txo_sum' => 150_000,
                     'spent_txo_count' => 1, 'spent_txo_sum' => 50_000 },
  'mempool_stats' => { 'tx_count' => 1, 'funded_txo_count' => 1, 'funded_txo_sum' => 20_000,
                       'spent_txo_count' => 0, 'spent_txo_sum' => 0 }
}.freeze

UTXO_JSON = {
  'txid' => 'ab' * 32, 'vout' => 1, 'value' => 75_000,
  'status' => { 'confirmed' => true, 'block_height' => 800_001, 'block_hash' => 'ff' * 32, 'block_time' => 1 }
}.freeze

TX_JSON = {
  'txid' => 'cd' * 32, 'version' => 2, 'locktime' => 0, 'size' => 222, 'weight' => 561, 'fee' => 1000,
  'status' => { 'confirmed' => true, 'block_height' => 800_002, 'block_hash' => 'ee' * 32,
                'block_time' => 1_720_000_000 }
}.freeze

M = Wallet::Api::Mempool::Mappers

check 'address: маппит адрес и статистики' do
  a = M.address(ADDRESS_JSON)
  assert_equal 'tb1qexample', a.address
  assert_equal 100_000, a.confirmed_balance
  assert_equal 20_000, a.unconfirmed_balance
  assert_equal 120_000, a.total_balance
end

check 'utxo: маппит подтверждённый выход' do
  u = M.utxo(UTXO_JSON)
  assert_equal 'ab' * 32, u.txid
  assert_equal 1, u.vout
  assert_equal 75_000, u.value
  assert_equal true, u.confirmed?
  assert_equal 800_001, u.block_height
end

check 'utxo: неподтверждённый выход (confirmed=false)' do
  u = M.utxo(UTXO_JSON.merge('status' => { 'confirmed' => false }))
  assert_equal false, u.confirmed?
  assert_nil u.block_height
end

check 'utxo: без status — неподтверждён, высота nil' do
  u = M.utxo(UTXO_JSON.reject { |k, _| k == 'status' })
  assert_equal false, u.confirmed?
  assert_nil u.block_height
end

check 'transaction: маппит поля и статус' do
  t = M.transaction(TX_JSON)
  assert_equal 'cd' * 32, t.txid
  assert_equal 2, t.version
  assert_equal 1000, t.fee
  assert_equal true, t.confirmed?
  assert_equal 800_002, t.block_height
  assert_equal 1_720_000_000, t.block_time
end

check 'transaction: без status — неподтверждена' do
  t = M.transaction(TX_JSON.reject { |k, _| k == 'status' })
  assert_equal false, t.confirmed?
  assert_nil t.block_height
  assert_nil t.block_time
end

check 'stats: маппит все счётчики' do
  s = M.stats(ADDRESS_JSON['chain_stats'])
  assert_equal 2, s.tx_count
  assert_equal 2, s.funded_txo_count
  assert_equal 150_000, s.funded_txo_sum
  assert_equal 1, s.spent_txo_count
  assert_equal 50_000, s.spent_txo_sum
end

check 'status: возвращает {} при отсутствии ключа' do
  assert_equal({}, M.status({}))
  assert_equal({ 'confirmed' => true }, M.status({ 'status' => { 'confirmed' => true } }))
end

check 'address: отсутствие обязательного ключа — KeyError' do
  assert_raises(KeyError) { M.address(ADDRESS_JSON.reject { |k, _| k == 'chain_stats' }) }
end

check 'utxo: отсутствие txid — KeyError' do
  assert_raises(KeyError) { M.utxo(UTXO_JSON.reject { |k, _| k == 'txid' }) }
end
