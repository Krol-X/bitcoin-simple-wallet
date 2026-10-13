# frozen_string_literal: true

# Тесты: lib/wallet/ui/presenter.rb
require_relative 'support'

FakeBalanceAccount = Struct.new(:address, :total_balance, :confirmed_balance, :unconfirmed_balance,
                                keyword_init: true)

P = Wallet::UI::Presenter.new

check 'to_sats: BTC -> сатоши' do
  assert_equal 100_000, P.to_sats('0.001')
  assert_equal 100_000_000, P.to_sats('1')
  assert_equal 0, P.to_sats('0')
end

check 'btc: сатоши -> BTC' do
  assert_equal 0.001, P.btc(100_000)
  assert_equal 0.0, P.btc(0)
end

check 'balance_lines: 4 строки с адресом и балансами' do
  account = FakeBalanceAccount.new(address: 'tb1qaddr', total_balance: 107_000,
                                   confirmed_balance: 100_000, unconfirmed_balance: 7_000)
  lines = P.balance_lines(account)
  assert_equal 4, lines.size
  assert_equal 'Адрес: tb1qaddr', lines[0]
  assert_equal 'Баланс: 107000 sats (0.00107 sBTC)', lines[1]
  assert_equal '  подтверждено: 100000 sats', lines[2]
  assert_equal '  в мемпуле:    7000 sats', lines[3]
end

check 'тексты отправки' do
  assert_equal 'Формируем транзакцию на 100000 sats...', P.sending(100_000)
  assert_equal 'Транзакция отправлена! TxID: abc123', P.sent('abc123')
end

check 'служебные тексты' do
  assert_match(/адрес получателя/, P.invalid_amount)
  assert_match(/-a/, P.unknown_command)
  assert_equal 'Ошибка: бум', P.error('бум')
  assert_equal ': ', P.prompt('Вопрос')[-2, 2]
  assert_equal ['1. Показать баланс', '2. Отправить', '3. Выход'], P.menu
end
