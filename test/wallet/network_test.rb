# frozen_string_literal: true

# Тесты: lib/wallet/api/core/network.rb
require_relative 'support'

N = Wallet::Api::Network

check 'validate! пропускает поддерживаемые сети и возвращает имя' do
  assert_equal :mainnet, N.validate!(:mainnet)
  assert_equal :signet, N.validate!(:signet)
  assert_equal :testnet4, N.validate!(:testnet4)
end

check 'validate! отклоняет неизвестную сеть' do
  e = assert_raises(Wallet::Api::ArgumentError, 'unknown network: bogus') { N.validate!(:bogus) }
  assert_match(/mainnet.*signet.*testnet4/, e.message)
end

check 'SUPPORTED содержит три сети' do
  assert_equal %i[mainnet signet testnet4], N::SUPPORTED
end
