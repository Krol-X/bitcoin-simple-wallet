# frozen_string_literal: true

# Тесты: lib/wallet/api/core/http_client.rb (HTTP подменён FakeHttp)
require_relative 'support'

class ProbeClient < Wallet::Api::HttpClient
  def get_json(url)
    request { |http| http.get(url) }
  end

  def post_raw(url, body)
    request_raw { |http| http.post(url, body: body) }
  end
end

URL = 'https://example.invalid/x'

check 'request: 200 — парсит JSON' do
  fake = FakeHttp.new({ [:get, URL] => [200, '{"a":1}'] })
  with_http_stub(fake) do
    assert_equal({ 'a' => 1 }, ProbeClient.new.get_json(URL))
  end
  assert_equal [[:get, URL]], fake.calls
end

check 'request_raw: 200 — возвращает тело строкой' do
  fake = FakeHttp.new({ [:post, URL] => [200, 'txid-hex'] })
  with_http_stub(fake) do
    assert_equal 'txid-hex', ProbeClient.new.post_raw(URL, 'body')
  end
end

check '400 — InvalidRequest' do
  fake = FakeHttp.new({ [:get, URL] => [400, 'bad'] })
  with_http_stub(fake) do
    assert_raises(Wallet::Api::InvalidRequest) { ProbeClient.new.get_json(URL) }
  end
end

check '404 — NotFound' do
  fake = FakeHttp.new({ [:get, URL] => [404, 'missing'] })
  with_http_stub(fake) do
    assert_raises(Wallet::Api::NotFound) { ProbeClient.new.get_json(URL) }
  end
end

check '500 и 503 — ServerError' do
  [500, 503].each do |code|
    fake = FakeHttp.new({ [:get, URL] => [code, 'oops'] })
    with_http_stub(fake) do
      assert_raises(Wallet::Api::ServerError) { ProbeClient.new.get_json(URL) }
    end
  end
end

check '302 — TransportError' do
  fake = FakeHttp.new({ [:get, URL] => [302, 'redirect'] })
  with_http_stub(fake) do
    assert_raises(Wallet::Api::TransportError) { ProbeClient.new.get_json(URL) }
  end
end

check 'таймаут по умолчанию 10, задаётся параметром' do
  assert_equal 10, ProbeClient.new.timeout
  assert_equal 3, ProbeClient.new(timeout: 3).timeout
end
