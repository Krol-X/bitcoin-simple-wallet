# frozen_string_literal: true

# Тесты: lib/wallet/ui/cli.rb
require_relative 'support'

FakeCliAccount = Struct.new(:address, :total_balance, :confirmed_balance, :unconfirmed_balance,
                            :sent, :error, keyword_init: true) do
  def address
    raise self[:error] if self[:error]

    self[:address]
  end

  def total_balance
    raise self[:error] if self[:error]

    self[:total_balance]
  end

  def confirmed_balance
    raise self[:error] if self[:error]

    self[:confirmed_balance]
  end

  def unconfirmed_balance
    raise self[:error] if self[:error]

    self[:unconfirmed_balance]
  end

  def send_funds(to:, amount:)
    raise self[:error] if self[:error]

    self[:sent] << [to, amount]
    'txid-cli-123'
  end
end

FakeArgs = Struct.new(:action, :address, :amount, keyword_init: true)

def cli_account(**over)
  FakeCliAccount.new(address: 'tb1qaddr', total_balance: 100_000, confirmed_balance: 100_000,
                     unconfirmed_balance: 0, sent: [], error: nil, **over)
end

def run_cli(account, args)
  out = StringIO.new
  cli = Wallet::UI::CLI.new(account: account, out: out)
  [cli.run(args), out.string]
end

check 'account: печатает баланс, возвращает 0' do
  status, out = run_cli(cli_account, FakeArgs.new(action: :account))
  assert_equal 0, status
  assert_match(/Адрес: tb1qaddr/, out)
  assert_match(/100000 sats/, out)
end

check 'send: конвертирует BTC в сатоши и печатает txid' do
  account = cli_account
  status, out = run_cli(account, FakeArgs.new(action: :send, address: 'tb1qdest', amount: '0.001'))
  assert_equal 0, status
  assert_equal [['tb1qdest', 100_000]], account.sent
  assert_match(/Формируем транзакцию на 100000 sats/, out)
  assert_match(/TxID: txid-cli-123/, out)
end

check 'send без адреса: ошибка, возврат 1' do
  account = cli_account
  status, out = run_cli(account, FakeArgs.new(action: :send, address: nil, amount: '0.001'))
  assert_equal 1, status
  assert_equal [], account.sent
  assert_match(/Укажите адрес получателя/, out)
end

check 'send с нулевой суммой: ошибка, возврат 1' do
  status, _out = run_cli(cli_account, FakeArgs.new(action: :send, address: 'tb1qdest', amount: '0'))
  assert_equal 1, status
end

check 'ошибка аккаунта: "Ошибка:", возврат 1' do
  account = cli_account(error: RuntimeError.new('сеть недоступна'))
  status, out = run_cli(account, FakeArgs.new(action: :account))
  assert_equal 1, status
  assert_match(/Ошибка: сеть недоступна/, out)
end

check 'неизвестное действие: подсказка, возврат 0' do
  status, out = run_cli(cli_account, FakeArgs.new(action: :repl))
  assert_equal 0, status
  assert_match(/Неизвестная команда/, out)
end
