# frozen_string_literal: true

# Тесты: lib/wallet/ui/repl.rb
require_relative 'support'

FakeReplAccount = Struct.new(:address, :total_balance, :confirmed_balance, :unconfirmed_balance,
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
    'txid-repl-456'
  end
end

def repl_account(**over)
  FakeReplAccount.new(address: 'tb1qaddr', total_balance: 50_000, confirmed_balance: 50_000,
                      unconfirmed_balance: 0, sent: [], error: nil, **over)
end

def run_repl(account, input_text)
  out = StringIO.new
  input = StringIO.new(input_text)
  repl = Wallet::UI::REPL.new(account: account, out: out, input: input)
  [repl.run, out.string]
end

check 'выход по "3" — возврат 0, меню показано' do
  status, out = run_repl(repl_account, "3\n")
  assert_equal 0, status
  assert_match(/1\. Показать баланс/, out)
end

check 'выход по "exit" и "quit"' do
  assert_equal 0, run_repl(repl_account, "exit\n")[0]
  assert_equal 0, run_repl(repl_account, "quit\n")[0]
end

check '"1" — показывает баланс' do
  status, out = run_repl(repl_account, "1\n3\n")
  assert_equal 0, status
  assert_match(/Адрес: tb1qaddr/, out)
  assert_match(/50000 sats/, out)
end

check '"2" — отправка: спрашивает адрес и сумму' do
  account = repl_account
  status, out = run_repl(account, "2\ntb1qdest\n0.002\n3\n")
  assert_equal 0, status
  assert_equal [['tb1qdest', 200_000]], account.sent
  assert_match(/TxID: txid-repl-456/, out)
end

check 'мусорный пункт — подсказка, цикл продолжается' do
  status, out = run_repl(repl_account, "wat\n3\n")
  assert_equal 0, status
  assert_match(/Неизвестная команда/, out)
end

check 'ошибка аккаунта — "Ошибка:", возврат 1' do
  account = repl_account(error: RuntimeError.new('сеть легла'))
  status, out = run_repl(account, "1\n")
  assert_equal 1, status
  assert_match(/Ошибка: сеть легла/, out)
end

check 'отправка с пустой суммой — ошибка, возврат 1' do
  status, out = run_repl(repl_account, "2\ntb1qdest\n\n")
  assert_equal 1, status
  assert_match(/Укажите адрес получателя/, out)
end
