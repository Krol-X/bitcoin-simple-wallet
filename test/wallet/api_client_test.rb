# frozen_string_literal: true

# Тесты: lib/wallet/api/client.rb
require_relative 'support'

class FakeProvider
  attr_reader :network, :calls

  def initialize(network:)
    @network = network
    @calls = []
  end

  def get_address(addr)
    @calls << [:get_address, addr]
    :address_dto
  end

  def get_utxo(addr)
    @calls << [:get_utxo, addr]
    [:utxo_dto]
  end

  def get_transaction(txid)
    @calls << [:get_transaction, txid]
    :tx_dto
  end

  def broadcast(hex)
    @calls << [:broadcast, hex]
    :txid
  end
end

check 'делегирует все методы провайдеру с теми же аргументами' do
  client = Wallet::Api::Client.new(network: :signet, provider: FakeProvider)
  assert_equal :address_dto, client.get_address('a')
  assert_equal [:utxo_dto], client.get_utxo('a')
  assert_equal :tx_dto, client.get_transaction('t')
  assert_equal :txid, client.broadcast('hex')
end

check 'передаёт сеть провайдеру' do
  client = Wallet::Api::Client.new(network: :testnet4, provider: FakeProvider)
  provider = client.instance_variable_get(:@provider)
  assert_equal :testnet4, provider.network
end

check 'неизвестная сеть — ошибка до создания провайдера' do
  created = false
  klass = Class.new(FakeProvider) do
    define_method(:initialize) { |**_| created = true }
  end
  assert_raises(Wallet::Api::ArgumentError, 'unknown network') do
    Wallet::Api::Client.new(network: :bogus, provider: klass)
  end
  assert_equal false, created
end

check 'провайдер по умолчанию — Mempool::Client' do
  client = Wallet::Api::Client.new(network: :signet)
  assert client.instance_variable_get(:@provider).is_a?(Wallet::Api::Mempool::Client)
end
