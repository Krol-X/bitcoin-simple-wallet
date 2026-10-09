# encoding: utf-8
# Проверка слоя совместимости с OpenSSL 3 + базовых сценариев подписи.
#
#   ruby test/openssl3_check.rb
#
# Ожидаемые значения сверены с двумя независимыми реализациями
# (python-embit и bip_utils) и с BIP32/BIP84 test vectors.
require 'bitcoin'
require_relative '../lib/bitcoin/signet'
require_relative '../lib/bitcoin/openssl3'

def check(name)
  res = yield
  puts "OK   #{name}#{res ? "  -> #{res.to_s[0, 70]}" : ''}"
  res
rescue => e
  puts "FAIL #{name}: #{e.class}: #{e.message[0, 140]}"
  nil
end

puts "OpenSSL: #{OpenSSL::OPENSSL_VERSION}"
puts "-" * 70

# 1. Генерация ключа
check("Key.generate") { k = Bitcoin::Key.generate; raise 'no pub' unless k.pub; k.pub }

# 2. Импорт приватного ключа + деривация публичного (BIP32 test vector 1)
V1_PRIV = "e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35".freeze
V1_PUB  = "0339a36013301597daef41fbe593a02cc513d0b55527ec2df1050e2e8ff49c85c2".freeze

check("Key.new(priv).pub (BIP32 vector 1)") do
  pub = Bitcoin::Key.new(V1_PRIV).pub
  raise "got #{pub}" unless pub == V1_PUB
  pub
end
check("pub_uncompressed") do
  pub = Bitcoin::Key.new(V1_PRIV).pub_uncompressed
  raise 'bad uncompressed' unless pub[0, 2] == "04" && pub.size == 130
  pub[0, 12]
end
check("WIF roundtrip (to_base58/from_base58)") do
  k  = Bitcoin::Key.new(V1_PRIV)
  k2 = Bitcoin::Key.from_base58(k.to_base58)
  raise 'mismatch' unless k2.pub == k.pub
  k.to_base58
end

# 3. Подпись/проверка хеша (как при подписи входов)
check("sign/verify hash") do
  k   = Bitcoin::Key.new(V1_PRIV)
  sig = k.sign("\x11" * 32)
  raise 'verify failed' unless k.verify("\x11" * 32, sig)
  raise 'verify must fail' if k.verify("\x12" * 32, sig)
  "#{sig.bytesize} bytes DER"
end
check("Bitcoin.verify_signature (сжатый и несжатый pub)") do
  k   = Bitcoin::Key.new(V1_PRIV)
  sig = k.sign("\x11" * 32)
  raise 'compressed pub fail'   unless Bitcoin.verify_signature("\x11" * 32, sig, k.pub)
  raise 'uncompressed pub fail' unless Bitcoin.verify_signature("\x11" * 32, sig, k.pub_uncompressed)
  true
end

# 4. Compact-подписи сообщений (отдельный FFI-путь)
check("sign_message/verify_message") do
  k = Bitcoin::Key.new(V1_PRIV)
  sig = k.sign_message("hello signet")
  raise 'verify_message failed' unless Bitcoin.verify_message(k.addr, sig, "hello signet")
  true
end

# 5. BIP32
V1_SEED = "000102030405060708090a0b0c0d0e0f".freeze
check("BIP32 master из seed (vector 1)") do
  master = Bitcoin::ExtKey.generate_master([V1_SEED].pack("H*"))
  raise "got #{master.priv}" unless master.priv == V1_PRIV
  master.priv
end
check("BIP32 m/0h/1/2h/2/1000000000 (vector 1)") do
  key = Bitcoin::ExtKey.generate_master([V1_SEED].pack("H*"))
        .derive(0x80000000).derive(1).derive(0x80000002).derive(2).derive(1000000000)
  expected = "471b76e389e528d6de6d816857e012c5455051cad6660850e58372a6c3e6e7c8"
  raise "got #{key.priv}" unless key.priv == expected
  key.priv
end
check("ExtPubkey#pub сжатый (vector 1)") do
  pub = Bitcoin::ExtKey.generate_master([V1_SEED].pack("H*")).ext_pubkey.pub
  raise "got #{pub}" unless pub == V1_PUB
  pub
end

# 6. BIP39 (mnemonic -> seed) и BIP84 account для testnet/signet
MNEMONIC = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".freeze
SEED_HEX = "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4".freeze

check("BIP39 to_seed (hex)") do
  # внимание: гем возвращает seed в виде hex-строки, для ExtKey нужен .htb
  seed = Bitcoin::Trezor::Mnemonic.to_seed(MNEMONIC)
  raise "got #{seed}" unless seed == SEED_HEX
  "#{seed[0, 16]}..."
end
check("BIP32 master из BIP39 seed") do
  master = Bitcoin::ExtKey.generate_master([SEED_HEX].pack("H*"))
  raise "got #{master.priv}" unless master.priv == "1837c1be8e2995ec11cda2b066151be2cfb48adf9e47b151d46adab3a21cdf67"
  master.priv
end

# BIP84: m/84'/1'/0'/0/0 (testnet-версия аккаунта, coin type 1')
BIP84_PRIV = "a9c4134b73560f43fc5c081e5c1daa7ce068adc806d80e1f37cb658e0fea4c8d".freeze
BIP84_ADDR = "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl".freeze

check("BIP84 m/84h/1h/0h/0/0 priv (signet/testnet)") do
  key = Bitcoin::ExtKey.generate_master([SEED_HEX].pack("H*"))
        .derive(0x80000054).derive(0x80000001).derive(0x80000000)
        .derive(0).derive(0)
  raise "got #{key.priv}" unless key.priv == BIP84_PRIV
  key.priv
end

check("BIP84 m/84h/1h/0h/0/0 -> tb1q адрес (signet)") do
  key = Bitcoin::ExtKey.generate_master([SEED_HEX].pack("H*"))
        .derive(0x80000054).derive(0x80000001).derive(0x80000000)
        .derive(0).derive(0)
  Bitcoin.network = :signet
  addr = Bitcoin.encode_segwit_address(0, Bitcoin.hash160(key.pub))
  raise "got #{addr}" unless addr == BIP84_ADDR
  addr
end
check("tprv корня для signet (extended_privkey_version)") do
  Bitcoin.network = :signet
  tprv = Bitcoin::ExtKey.generate_master([SEED_HEX].pack("H*")).to_base58
  expected = "tprv8ZgxMBicQKsPe5YMU9gHen4Ez3ApihUfykaqUorj9t6FDqy3nP6eoXiAo2ssvpAjoLroQxHqr3R5nE3a5dU3DHTjTgJDd7zrbniJr6nrCzd"
  raise "got #{tprv}" unless tprv == expected
  tprv[0, 24] + "..."
end

puts
puts "Готово."
