# encoding: utf-8
# Проверка библиотеки на РЕАЛЬНЫХ транзакциях signet:
# скачиваем транзакцию и её prevout'ы через публичный API mempool.space,
# парсим их гемом и проверяем подписи входов.
#
#   ruby test/bitcoin/verify_real_signet_tx.rb 480ac0dceaa9c8448f8da790715f9e4142faa5d49dc26342ce0f118f623ce8c4
#   ruby test/bitcoin/verify_real_signet_tx.rb <txid1> <txid2> ...
#
# Без аргументов берёт несколько транзакций из верхушки блокчейна signet.
require 'stringio'
require 'bitcoin'
require 'net/http'
require 'json'
require_relative '../../lib/bitcoin/signet'
require_relative '../../lib/bitcoin/openssl3'

Bitcoin.network = :signet

API = "https://mempool.space/signet/api".freeze

def api_get(path)
  uri = URI("#{API}#{path}")
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 30) do |http|
    http.get(uri.request_uri)
  end
  raise "HTTP #{res.code} for #{path}" unless res.code == "200"
  JSON.parse(res.body)
end

def api_get_text(path)
  uri = URI("#{API}#{path}")
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 30) do |http|
    http.get(uri.request_uri)
  end
  raise "HTTP #{res.code} for #{path}" unless res.code == "200"
  res.body.strip
end

def script_kind(script_hex)
  return :coinbase if script_hex.nil? || script_hex.empty?
  case script_hex[0, 4]
  when "0014" then :p2wpkh
  when "0020" then :p2wsh
  when "5120" then :p2tr
  when "76a9" then :p2pkh
  else
    script_hex[0, 2] == "a9" ? :p2sh : :other
  end
end

def verify_tx(txid)
  data = api_get("/tx/#{txid}")
  raw  = api_get_text("/tx/#{txid}/hex")
  tx   = Bitcoin::Protocol::Tx.new([raw].pack('H*'))

  puts "tx #{txid}"
  puts "   размер: #{data['size']} B (vsize #{(data['weight'] / 4.0).ceil}), входов #{tx.in.size}, выходов #{tx.out.size}"
  raise "txid mismatch!" unless tx.hash == txid
  puts "   txid пересчитан гемом: OK"

  ok = skip = fail = 0
  tx.in.each_with_index do |input, idx|
    prevout = data['vin'][idx]['prevout']
    spk_hex = prevout && prevout['scriptpubkey']
    kind    = script_kind(spk_hex)
    if input.coinbase?
      puts "   [#{idx}] coinbase — пропуск"; skip += 1; next
    end

    case kind
    when :p2wpkh
      res = tx.verify_witness_input_signature(idx, [spk_hex].pack('H*'), prevout['value'])
    when :p2pkh
      res = tx.verify_input_signature(idx, [spk_hex].pack('H*'))
    else
      puts "   [#{idx}] #{kind} — тип не поддерживается гемом, пропуск"
      skip += 1
      next
    end

    puts "   [#{idx}] #{kind} #{res ? 'подпись ВЕРНА' : 'подпись НЕВЕРНА'}"
    res ? ok += 1 : fail += 1
  end

  puts "   итог: проверено #{ok}, пропущено #{skip}, ошибок #{fail}"
  fail.zero?
end

txids = ARGV
if txids.empty?
  # ищем в последних блоках транзакции, которые гем умеет проверять (не taproot)
  txids = []
  api_get("/blocks").first(3).each do |block|
    break if txids.size >= 3
    api_get("/block/#{block['id']}/txids").each do |txid|
      break if txids.size >= 3
      data = api_get("/tx/#{txid}")
      next if data['vin'][0]['is_coinbase']
      next unless data['vin'].any? { |v| kind = script_kind((v['prevout'] || {})['scriptpubkey']); [:p2wpkh, :p2pkh].include?(kind) }
      txids << txid
    end
  end
  puts "выбраны транзакции с P2WPKH/P2PKH входами: #{txids.size}"
end

puts "=" * 70
results = txids.map { |txid| verify_tx(txid) rescue (puts "   ОШИБКА: #{$!.class}: #{$!.message}"; false) }
puts "=" * 70
puts results.all? ? "Все проверенные транзакции signet валидны." : "Есть расхождения, смотрите вывод выше."
