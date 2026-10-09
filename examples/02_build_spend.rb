# encoding: utf-8
# Создание и подпись транзакций для signet: P2WPKH, P2SH-P2WPKH и P2PKH.
#
#   ruby examples/02_build_spend.rb
#
# Пример полностью оффлайновый: «входы» (funding tx) сфабрикованы локально,
# поэтому для проверки не нужны монеты и интернет. Хеши подписи зависят только
# от txid/скрипта/суммы, поэтому подписи здесь настоящие и валидные —
# ровно такие же, как если бы вы брали UTXO через API/ноду.
require 'stringio'
require 'json'
require 'bitcoin'
require_relative '../lib/bitcoin/signet'
require_relative '../lib/bitcoin/openssl3'

Bitcoin.network = :signet

# DSL-методы билдера (build_tx и т.п.)
include Bitcoin::Builder

# Фиксированные ключи, чтобы результат был воспроизводим.
OWNER_PRIV     = "1111111111111111111111111111111111111111111111111111111111111111".freeze
RECIPIENT_PRIV = "2222222222222222222222222222222222222222222222222222222222222222".freeze

owner     = Bitcoin::Key.new(OWNER_PRIV)
recipient = Bitcoin::Key.new(RECIPIENT_PRIV)

def p2wpkh_script(key)      = Bitcoin::Script.to_witness_hash160_script(key.hash160)
def p2wpkh_address(key)     = Bitcoin.encode_segwit_address(0, key.hash160)
def p2pkh_script(key)       = Bitcoin::Script.to_hash160_script(key.hash160)
def p2sh_p2wpkh_script(key) = Bitcoin::Script.to_p2sh_script(Bitcoin.hash160(p2wpkh_script(key).bth))
def p2sh_p2wpkh_address(key)= Bitcoin.hash160_to_p2sh_address(Bitcoin.hash160(p2wpkh_script(key).bth))

# ВАЖНО: после сборки segwit-транзакции Bitcoin::Builder кладёт в tx.hash хеш
# от witness-сериализации (по сути wtxid), а НЕ txid. Настоящий txid — это
# sha256d от «старого» формата без witness. Вот хелпер, который это исправляет:
def tx_txid(tx)
  tx.refresh_hash                                    # @hash = sha256d(to_old_payload)
  tx.instance_variable_set(:@binary_hash, nil)       # сбрасываем кеш binary_hash
  tx.hash
end

# Транзакция, «заплатившая» нам — заменяет реальный UTXO из сети.
# coinbase_data задаём фиксированным, чтобы пример был воспроизводимым.
def fake_funding_tx(address, amount, tag)
  Bitcoin::Builder.build_tx do |t|
    t.input { |i| i.coinbase(Digest::SHA256.hexdigest(tag)) }
    t.output { |o| o.value(amount); o.script { |s| s.recipient(address) } }
  end
end

results = []

def report(name, tx, fee, extra = {})
  hex  = tx.to_payload.bth
  txid = tx_txid(tx)
  puts "#{name}"
  puts "   txid  : #{txid}"
  puts "   размер: #{tx.to_payload.bytesize} B, fee #{fee} sat (fee rate #{(fee / (tx.to_payload.bytesize / 1000.0)).round(1)} sat/kvB)"
  puts "   raw   : #{hex[0, 64]}...#{hex[-16..]}"
  extra.each { |k, v| puts "   #{k}: #{v}" }
  puts
  { name: name, txid: txid, hex: hex, fee: fee }.merge(extra)
end

puts "=" * 78
puts "Signet: адреса"
puts "=" * 78
puts "owner P2WPKH     : #{p2wpkh_address(owner)}"
puts "owner P2SH-P2WPKH: #{p2sh_p2wpkh_address(owner)}"
puts "owner P2PKH      : #{owner.addr}"
puts "recipient P2WPKH : #{p2wpkh_address(recipient)}"
puts

# ---------------------------------------------------------------------------
puts "=" * 78
puts "1) Трата P2WPKH (tb1q...) — сегвит v0, BIP143"
puts "=" * 78
funding = fake_funding_tx(p2wpkh_address(owner), 100_000, 'signet-example-p2wpkh')
puts "   UTXO: #{funding.hash}:0 -> #{p2wpkh_address(owner)} (100000 sat)"

tx1 = Bitcoin::Builder.build_tx do |t|
  t.version 2
  t.input do |i|
    i.prev_out funding, 0          # берём скрипт и индекс из funding-транзакции
    i.prev_out_value 100_000       # обязательно для segwit
    i.signature_key owner
  end
  t.output do |o|
    o.value 30_000
    o.script { |s| s.recipient(p2wpkh_address(recipient)) }
  end
  t.output do |o|                  # сдача
    o.value 69_000
    o.script { |s| s.recipient(p2wpkh_address(owner)) }
  end
end

ok1 = tx1.verify_witness_input_signature(0, funding.out[0].pk_script, 100_000)
puts "   подпись проверена гемом: #{ok1}"
raise 'bad signature' unless ok1
results << report("1) P2WPKH", tx1, 1000, { inputs: [{ spk: funding.out[0].pk_script.bth, value: 100_000, priv: OWNER_PRIV }] })

# ---------------------------------------------------------------------------
puts "=" * 78
puts "2) Трата P2SH-P2WPKH (2...) — redeem_script + segwit"
puts "=" * 78
funding2 = fake_funding_tx(p2sh_p2wpkh_address(owner), 200_000, 'signet-example-p2sh')
puts "   UTXO: #{funding2.hash}:0 -> #{p2sh_p2wpkh_address(owner)} (200000 sat)"

tx2 = Bitcoin::Builder.build_tx do |t|
  t.version 2
  t.input do |i|
    i.prev_out funding2, 0
    i.prev_out_value 200_000
    i.redeem_script p2wpkh_script(owner)   # для P2SH нужен redeem script
    i.signature_key owner
  end
  t.output do |o|
    o.value 199_000
    o.script { |s| s.recipient(p2wpkh_address(recipient)) }
  end
end

ok2 = tx2.verify_witness_input_signature(0, funding2.out[0].pk_script, 200_000)
puts "   подпись проверена гемом: #{ok2}"
raise 'bad signature' unless ok2
results << report("2) P2SH-P2WPKH", tx2, 1000, { inputs: [{ spk: funding2.out[0].pk_script.bth, value: 200_000, priv: OWNER_PRIV }] })

# ---------------------------------------------------------------------------
puts "=" * 78
puts "3) Трата P2PKH (m.../n...) — legacy, scriptSig"
puts "=" * 78
funding3 = fake_funding_tx(owner.addr, 150_000, 'signet-example-p2pkh')
puts "   UTXO: #{funding3.hash}:0 -> #{owner.addr} (150000 sat)"

tx3 = Bitcoin::Builder.build_tx do |t|
  t.version 2
  t.input do |i|
    i.prev_out funding3, 0
    i.signature_key owner
  end
  t.output do |o|
    o.value 149_000
    o.script { |s| s.recipient(p2wpkh_address(recipient)) }
  end
end

ok3 = tx3.verify_input_signature(0, funding3.out[0].pk_script)
puts "   подпись проверена гемом: #{ok3}"
raise 'bad signature' unless ok3
results << report("3) P2PKH", tx3, 1000, { inputs: [{ spk: funding3.out[0].pk_script.bth, value: 150_000, priv: OWNER_PRIV }] })

# ---------------------------------------------------------------------------
puts "=" * 78
puts "4) Два входа + авто-сдача (change_address/input_value/leave_fee)"
puts "=" * 78
funding4 = build_tx do |t|
  t.input { |i| i.coinbase(Digest::SHA256.hexdigest('signet-example-multi')) }
  t.output { |o| o.value(60_000); o.script { |s| s.recipient(p2wpkh_address(owner)) } }
  t.output { |o| o.value(60_000); o.script { |s| s.recipient(p2wpkh_address(owner)) } }
end
puts "   UTXOs: #{funding4.hash}:0 и :1 по 60000 sat"

builder = Bitcoin::Builder::TxBuilder.new
builder.version 2
[0, 1].each do |idx|
  builder.input do |i|
    i.prev_out funding4, idx
    i.prev_out_value 60_000
    i.signature_key owner
  end
end
builder.output do |o|
  o.value 100_000
  o.script { |s| s.recipient(p2wpkh_address(recipient)) }
end
# сдача считается автоматически: 120000 - 100000 - комиссия
tx4 = builder.tx(change_address: p2wpkh_address(owner), input_value: 120_000, leave_fee: true)

ok4 = [0, 1].all? { |i| tx4.verify_witness_input_signature(i, funding4.out[i].pk_script, 60_000) }
puts "   подписи двух входов проверены гемом: #{ok4}"
raise 'bad signature' unless ok4
results << report("4) 2 входа + авто-сдача", tx4, 120_000 - tx4.out.map(&:value).sum, {
  inputs: [
    { spk: funding4.out[0].pk_script.bth, value: 60_000, priv: OWNER_PRIV },
    { spk: funding4.out[1].pk_script.bth, value: 60_000, priv: OWNER_PRIV }
  ]
})

# ---------------------------------------------------------------------------
puts "=" * 78
puts "Все транзакции подписаны и проверены локально: #{results.map { |r| r[:name] }.join(', ')}"
puts "=" * 78

require 'fileutils'
FileUtils.mkdir_p(File.join(__dir__, '../build'))
File.write(File.join(__dir__, '../build/spends.json'),
           JSON.pretty_generate('network' => 'signet', 'spends' => results))

puts
puts "Данные для независимой проверки сохранены в build/spends.json"
puts "Проверить: python3 test/crosscheck_embit.py"
puts
puts "Отправить в сеть можно, например, так (нужны монеты на входе):"
puts "  curl -X POST -d \"$(jq -r '.spends[0].hex' build/spends.json)\" https://mempool.space/signet/api/tx"
