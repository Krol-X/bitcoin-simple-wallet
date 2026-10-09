# encoding: utf-8
# Ключи и адреса signet.
#
#   ruby examples/01_addresses.rb
require 'stringio'
require 'bitcoin'
require_relative '../lib/bitcoin/signet'
require_relative '../lib/bitcoin/openssl3'

Bitcoin.network = :signet

puts "network_name : #{Bitcoin.network_name}"
puts "magic_head   : #{Bitcoin.network[:magic_head].unpack('H*').first} (wire: 0a 03 cf 40)"
puts "genesis      : #{Bitcoin.network[:genesis_hash]}"
puts "port         : #{Bitcoin.network[:default_port]}"
puts

key = Bitcoin::Key.generate(compressed: true)
puts "priv (WIF)   : #{key.to_base58}"
puts "pub          : #{key.pub}"
puts "hash160      : #{key.hash160}"
puts

p2pkh  = key.addr                                            # m.../n...
p2wpkh = Bitcoin.encode_segwit_address(0, key.hash160)       # tb1q...
redeem = Bitcoin::Script.to_witness_hash160_script(key.hash160)
p2sh   = Bitcoin.hash160_to_p2sh_address(Bitcoin.hash160(redeem.bth)) # p2sh-p2wpkh, 2...

puts "P2PKH        : #{p2pkh}   (#{Bitcoin.address_type(p2pkh)})"
puts "P2SH-P2WPKH  : #{p2sh}   (#{Bitcoin.address_type(p2sh)})"
puts "P2WPKH       : #{p2wpkh}  (#{Bitcoin.address_type(p2wpkh)})"
puts

# Проверяем, что адрес корректно декодируется обратно и превращается в скрипт
raise "addr_type mismatch" unless Bitcoin.address_type(p2wpkh) == :witness_v0_keyhash
raise "roundtrip mismatch" unless Bitcoin.decode_segwit_address(p2wpkh) == [0, key.hash160]
raise "valid_address? failed" unless Bitcoin.valid_address?(p2pkh) && Bitcoin.valid_address?(p2sh) && Bitcoin.valid_address?(p2wpkh)

scr = Bitcoin::Script.to_address_script(p2wpkh)
puts "scriptPubKey : #{scr.bth}"
puts "decoded back : #{Bitcoin::Script.new(scr).get_address}"
raise "script->address mismatch" unless Bitcoin::Script.new(scr).get_address == p2wpkh

# WIF, импортированный обратно, даёт тот же публичный ключ
raise "WIF roundtrip failed" unless Bitcoin::Key.from_base58(key.to_base58).pub == key.pub

puts
puts "OK: signet-адреса генерируются и разбираются корректно."
