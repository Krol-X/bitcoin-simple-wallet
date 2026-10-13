# frozen_string_literal: true

# Тесты: lib/wallet/account.rb (сеть — фейковый клиент, криптография настоящая)
require_relative 'support'

class FakeApiClient
  attr_reader :calls

  def initialize(address_info:, utxos:, broadcast_result: 'dd' * 32)
    @address_info = address_info
    @utxos = utxos
    @broadcast_result = broadcast_result
    @calls = []
  end

  def get_address(addr)
    @calls << [:get_address, addr]
    @address_info
  end

  def get_utxo(addr)
    @calls << [:get_utxo, addr]
    @utxos
  end

  def broadcast(hex)
    @calls << [:broadcast, hex]
    @broadcast_result
  end
end

def test_account(utxos: [], chain_funded: 0, chain_spent: 0, mem_funded: 0, mem_spent: 0)
  dir = Dir.mktmpdir
  key = Wallet::PrivateKey.new(File.join(dir, 'wallet.key'))
  addr = key_address(key.value)
  info = make_address(addr, chain_funded: chain_funded, chain_spent: chain_spent,
                            mem_funded: mem_funded, mem_spent: mem_spent)
  client = FakeApiClient.new(address_info: info, utxos: utxos)
  [Wallet::Account.new(key: key, client: client, network: :signet), client, key]
end

check 'address — segwit-адрес signet из hash160 ключа' do
  account, _client, key = test_account
  assert_equal key_address(key.value), account.address
  assert_match(/\Atb1q/, account.address)
end

check 'address_info и utxos кэшируются (один поход в сеть)' do
  account, client, _key = test_account(utxos: [make_utxo(value: 10)])
  account.address_info
  account.address_info
  account.utxos
  account.utxos
  assert_equal 1, client.calls.count { |c| c[0] == :get_address }
  assert_equal 1, client.calls.count { |c| c[0] == :get_utxo }
end

check 'балансы делегируются DTO адреса' do
  account, = test_account(chain_funded: 100_000, chain_spent: 30_000, mem_funded: 5_000, mem_spent: 1_000)
  assert_equal 70_000, account.confirmed_balance
  assert_equal 4_000, account.unconfirmed_balance
  assert_equal 74_000, account.total_balance
end

check 'spendable_utxos — только подтверждённые' do
  confirmed = make_utxo(value: 50_000, confirmed: true)
  pending = make_utxo(value: 60_000, confirmed: false)
  account, = test_account(utxos: [confirmed, pending])
  assert_equal [confirmed], account.spendable_utxos
end

check 'refresh! сбрасывает кэш и возвращает self' do
  account, client, = test_account(utxos: [make_utxo(value: 10)])
  account.address_info
  account.utxos
  assert_equal account, account.refresh!
  account.address_info
  account.utxos
  assert_equal 2, client.calls.count { |c| c[0] == :get_address }
  assert_equal 2, client.calls.count { |c| c[0] == :get_utxo }
end

check 'send_funds: broadcast-ит hex и возвращает txid транзакции' do
  dest = key_address(make_key)
  utxo = make_utxo(value: 100_000)
  account, client, = test_account(utxos: [utxo])
  txid = account.send_funds(to: dest, amount: 50_000)
  method, hex = client.calls.find { |c| c[0] == :broadcast }
  assert method, 'broadcast был вызван'
  assert_equal txid_of_hex(hex), txid
  parsed = Bitcoin::Protocol::Tx.new(hex.htb)
  assert_equal [50_000, 49_000], parsed.out.map(&:value)
end

check 'конструктор выставляет сеть Bitcoin (signet)' do
  test_account
  assert_equal 'tb', Bitcoin.network[:bech32_hrp]
end
