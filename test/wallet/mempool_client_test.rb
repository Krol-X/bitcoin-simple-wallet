# frozen_string_literal: true

# Тесты: lib/wallet/api/mempool/{client,addresses,transactions}.rb (HTTP подменён)
require_relative 'support'

C = Wallet::Api::Mempool::Client

ADDR = 'tb1qexampleaddr'
SIGNET_GW = 'https://mempool.space/signet/api'
MAINNET_GW = 'https://mempool.space/api'

ADDRESS_BODY = {
  'address' => ADDR,
  'chain_stats' => { 'tx_count' => 1, 'funded_txo_count' => 1, 'funded_txo_sum' => 90_000,
                     'spent_txo_count' => 0, 'spent_txo_sum' => 0 },
  'mempool_stats' => { 'tx_count' => 0, 'funded_txo_count' => 0, 'funded_txo_sum' => 0,
                       'spent_txo_count' => 0, 'spent_txo_sum' => 0 }
}.to_json

UTXO_BODY = [
  { 'txid' => 'aa' * 32, 'vout' => 0, 'value' => 90_000,
    'status' => { 'confirmed' => true, 'block_height' => 200 } },
  { 'txid' => 'bb' * 32, 'vout' => 1, 'value' => 5_000,
    'status' => { 'confirmed' => false } }
].to_json

TX_BODY = {
  'txid' => 'cc' * 32, 'version' => 2, 'locktime' => 0, 'size' => 200, 'weight' => 500, 'fee' => 500,
  'status' => { 'confirmed' => true, 'block_height' => 201, 'block_time' => 1_700_000_000 }
}.to_json

check 'get_address: ходит на signet-gateway и маппит DTO' do
  url = "#{SIGNET_GW}/address/#{ADDR}"
  fake = FakeHttp.new({ [:get, url] => [200, ADDRESS_BODY] })
  with_http_stub(fake) do
    a = C.new(network: :signet).get_address(ADDR)
    assert_equal ADDR, a.address
    assert_equal 90_000, a.confirmed_balance
  end
  assert_equal [[:get, url]], fake.calls
end

check 'get_utxo: возвращает массив DTO, confirmed различаются' do
  url = "#{SIGNET_GW}/address/#{ADDR}/utxo"
  fake = FakeHttp.new({ [:get, url] => [200, UTXO_BODY] })
  with_http_stub(fake) do
    utxos = C.new(network: :signet).get_utxo(ADDR)
    assert_equal 2, utxos.size
    assert_equal true, utxos[0].confirmed?
    assert_equal 90_000, utxos[0].value
    assert_equal false, utxos[1].confirmed?
  end
end

check 'get_transaction: маппит транзакцию' do
  txid = 'cc' * 32
  url = "#{SIGNET_GW}/tx/#{txid}"
  fake = FakeHttp.new({ [:get, url] => [200, TX_BODY] })
  with_http_stub(fake) do
    t = C.new(network: :signet).get_transaction(txid)
    assert_equal txid, t.txid
    assert_equal 500, t.fee
    assert_equal true, t.confirmed?
  end
end

check 'broadcast: POST /tx возвращает txid строкой' do
  url = "#{SIGNET_GW}/tx"
  fake = FakeHttp.new({ [:post, url] => [200, 'dd' * 32] })
  with_http_stub(fake) do
    assert_equal 'dd' * 32, C.new(network: :signet).broadcast('deadbeef')
  end
  assert_equal [[:post, url]], fake.calls
end

check 'mainnet использует свой gateway' do
  url = "#{MAINNET_GW}/address/#{ADDR}"
  fake = FakeHttp.new({ [:get, url] => [200, ADDRESS_BODY] })
  with_http_stub(fake) do
    C.new(network: :mainnet).get_address(ADDR)
  end
  assert_equal [[:get, url]], fake.calls
end

check 'ошибка API пробрасывается (404 -> NotFound)' do
  url = "#{SIGNET_GW}/address/#{ADDR}"
  fake = FakeHttp.new({ [:get, url] => [404, 'not found'] })
  with_http_stub(fake) do
    assert_raises(Wallet::Api::NotFound) { C.new(network: :signet).get_address(ADDR) }
  end
end

check 'неизвестная сеть — KeyError из GATEWAYS.fetch' do
  assert_raises(KeyError) { C.new(network: :bogus) }
end
