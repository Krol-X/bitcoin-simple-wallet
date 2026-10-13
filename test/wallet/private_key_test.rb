# frozen_string_literal: true

# Тесты: lib/wallet/private_key.rb
require_relative 'support'

def tmp_key_path(dir, name = 'wallet.key')
  File.join(dir, name)
end

check 'создаёт новый ключ и файл 0600 при отсутствии файла' do
  Dir.mktmpdir do |dir|
    path = tmp_key_path(dir)
    pk = Wallet::PrivateKey.new(path)
    assert File.exist?(path), 'файл ключа создан'
    assert_equal 0o600, File.stat(path).mode & 0o777
    assert_equal "#{pk.value.to_base58}\n", File.read(path)
    assert_equal path, pk.key_file
  end
end

check 'повторная загрузка возвращает тот же ключ' do
  Dir.mktmpdir do |dir|
    path = tmp_key_path(dir)
    wif = Wallet::PrivateKey.new(path).value.to_base58
    again = Wallet::PrivateKey.new(path)
    assert_equal wif, again.value.to_base58
  end
end

check 'чинит права файла (644 -> 600) при загрузке' do
  Dir.mktmpdir do |dir|
    path = tmp_key_path(dir)
    wif = Wallet::PrivateKey.new(path).value.to_base58
    File.chmod(0o644, path)
    reloaded = Wallet::PrivateKey.new(path)
    assert_equal wif, reloaded.value.to_base58
    assert_equal 0o600, File.stat(path).mode & 0o777
  end
end

check 'пустой файл — генерирует новый ключ' do
  Dir.mktmpdir do |dir|
    path = tmp_key_path(dir)
    File.write(path, "  \n")
    pk = Wallet::PrivateKey.new(path)
    assert pk.value, 'ключ сгенерирован'
    assert_match(/\S+/, File.read(path).strip)
  end
end

check 'мусор в файле — понятная ошибка' do
  Dir.mktmpdir do |dir|
    path = tmp_key_path(dir)
    File.write(path, "not-a-key\n")
    e = assert_raises(RuntimeError, 'Не удалось прочитать ключ') do
      Wallet::PrivateKey.new(path)
    end
    assert_match(path, e.message)
  end
end

check 'save_key создаёт вложенные директории' do
  Dir.mktmpdir do |dir|
    path = File.join(dir, 'a', 'b', 'wallet.key')
    Wallet::PrivateKey.new(path)
    assert File.exist?(path), 'файл создан во вложенной директории'
  end
end

check 'inspect не раскрывает WIF' do
  Dir.mktmpdir do |dir|
    path = tmp_key_path(dir)
    pk = Wallet::PrivateKey.new(path)
    assert_match(path, pk.inspect)
    assert !pk.inspect.include?(pk.value.to_base58), 'WIF не должен попадать в inspect'
  end
end
