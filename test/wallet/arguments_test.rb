# frozen_string_literal: true

# Тесты: lib/wallet/ui/arguments.rb
require_relative 'support'

A = Wallet::UI::Arguments

def quietly
  orig_out, orig_err = $stdout, $stderr
  $stdout = StringIO.new
  $stderr = StringIO.new
  yield
ensure
  $stdout = orig_out
  $stderr = orig_err
end

check 'без аргументов — REPL' do
  args = A.parse([])
  assert_equal true, args.repl?
  assert_equal :repl, args.action
end

check '-a — баланс' do
  args = A.parse(['-a'])
  assert_equal :account, args.action
  assert_equal false, args.repl?
end

check '--account — баланс (длинный флаг)' do
  assert_equal :account, A.parse(['--account']).action
end

check '-s ADDR AMOUNT — отправка' do
  args = A.parse(['-s', 'tb1qaddr', '0.001'])
  assert_equal :send, args.action
  assert_equal 'tb1qaddr', args.address
  assert_equal '0.001', args.amount
end

check '--send — отправка (длинный флаг)' do
  args = A.parse(['--send', 'tb1qaddr', '1.5'])
  assert_equal :send, args.action
  assert_equal 'tb1qaddr', args.address
  assert_equal '1.5', args.amount
end

check 'неизвестный флаг — выход со статусом 2' do
  e = assert_raises(SystemExit) { quietly { A.parse(['--bogus']) } }
  assert_equal 2, e.status
end

check '-h — помощь и выход со статусом 0' do
  e = assert_raises(SystemExit) { quietly { A.parse(['-h']) } }
  assert_equal 0, e.status
end
