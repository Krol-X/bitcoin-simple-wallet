# frozen_string_literal: true

# Общий хелпер для тестов lib/wallet.
#
#   mise exec -- bundle exec ruby test/wallet/dto_test.rb
#   bash test/wallet/run_all.sh   # весь набор
#
# Стиль — как в test/bitcoin: plain-Ruby без внешних зависимостей
# (minitest недоступен под `bundle exec`, его нет в Gemfile).
# Все тесты офлайн: сеть подменяется FakeHttp, ключи генерируются локально.

require 'stringio'
require 'tmpdir'
require 'securerandom'
require 'json'

require_relative '../../lib/wallet'
require_relative '../../lib/wallet/ui/arguments'
require_relative '../../lib/wallet/ui/cli'
require_relative '../../lib/wallet/ui/repl'

Bitcoin.network = :signet

class TestFailure < StandardError; end

$failures = []

def check(name)
  yield
  puts "OK   #{name}"
rescue TestFailure => e
  puts "FAIL #{name}: #{e.message}"
  $failures << name
rescue StandardError => e
  puts "ERROR #{name}: #{e.class}: #{e.message.to_s[0, 200]}"
  $failures << name
end

def assert(cond, message = 'assertion failed')
  raise TestFailure, message unless cond
end

def assert_equal(expected, actual, message = nil)
  return if expected == actual

  prefix = message ? "#{message}: " : ''
  raise TestFailure, "#{prefix}expected #{expected.inspect}, got #{actual.inspect}"
end

def assert_nil(actual, message = nil)
  prefix = message ? "#{message}: " : ''
  raise TestFailure, "#{prefix}expected nil, got #{actual.inspect}" unless actual.nil?
end

def assert_match(pattern, string, message = nil)
  prefix = message ? "#{message}: " : ''
  matched = pattern.is_a?(String) ? string.include?(pattern) : (pattern =~ string)
  raise TestFailure, "#{prefix}expected #{string.inspect} to match #{pattern.inspect}" unless matched
end

def assert_raises(expected_class, expected_message = nil)
  yield
  raise TestFailure, "expected #{expected_class} but nothing was raised"
rescue TestFailure
  raise
rescue expected_class => e
  if expected_message
    ok = expected_message.is_a?(Regexp) ? (expected_message =~ e.message) : e.message.include?(expected_message.to_s)
    unless ok
      raise TestFailure, "exception message #{e.message.inspect} does not match #{expected_message.inspect}"
    end
  end
  e
end

# --- Подмена HTTP-слоя (Wallet::Api::HttpClient дергает HTTP.timeout) ---

FakeHttpStatus = Struct.new(:code)
FakeHttpResponse = Struct.new(:status, :body) do
  def to_s
    "HTTP #{status.code}: #{body.to_s[0, 120]}"
  end
end

class FakeHttp
  attr_reader :calls

  # routes: { [:get, url] => [status_code, body], [:post, url] => [status_code, body] }
  def initialize(routes = {})
    @routes = routes
    @calls = []
  end

  def get(url)
    record(:get, url)
  end

  def post(url, body: nil) # rubocop:disable Lint/UnusedMethodArgument
    record(:post, url)
  end

  private

  def record(method, url)
    @calls << [method, url]
    code, body = @routes.fetch([method, url]) { raise TestFailure, "unexpected HTTP call: #{method.to_s.upcase} #{url}" }
    FakeHttpResponse.new(FakeHttpStatus.new(code), body)
  end
end

def with_http_stub(fake)
  original = HTTP.method(:timeout)
  HTTP.define_singleton_method(:timeout) { |*_, **_| fake }
  yield
ensure
  HTTP.define_singleton_method(:timeout, original)
end

# --- Фабрики DTO ---

def make_stats(funded:, spent:, txs: 1)
  Wallet::Dto::Stats.new(
    tx_count: txs, funded_txo_count: txs, funded_txo_sum: funded,
    spent_txo_count: txs, spent_txo_sum: spent
  )
end

def make_address(addr, chain_funded: 0, chain_spent: 0, mem_funded: 0, mem_spent: 0)
  Wallet::Dto::Address.new(
    address: addr,
    chain_stats: make_stats(funded: chain_funded, spent: chain_spent),
    mempool_stats: make_stats(funded: mem_funded, spent: mem_spent, txs: 0)
  )
end

def make_utxo(value:, confirmed: true, vout: 0, txid: nil, block_height: 800_000)
  Wallet::Dto::Utxo.new(
    txid: txid || SecureRandom.hex(32), vout: vout, value: value,
    confirmed: confirmed, block_height: confirmed ? block_height : nil
  )
end

def make_key
  Bitcoin::Key.generate
end

def key_address(key)
  Bitcoin.encode_segwit_address(0, key.hash160)
end

# txid по тем же правилам, что Wallet::Transaction#real_txid
def txid_of_hex(hex)
  tx = Bitcoin::Protocol::Tx.new(hex.htb)
  tx.refresh_hash
  tx.instance_variable_set(:@binary_hash, nil)
  tx.hash
end

at_exit do
  # Падение вне check-блоков (например, NameError на верхнем уровне файла):
  # $! — необработанное исключение, завершающее процесс.
  if $! && !$!.is_a?(SystemExit)
    $failures << "load error: #{$!.class}: #{$!.message.to_s[0, 160]}"
  end
  if $failures.empty?
    puts 'PASS'
  else
    puts "FAILURES (#{$failures.size}): #{$failures.join(', ')}"
  end
  exit($failures.empty? ? 0 : 1)
end
