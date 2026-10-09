# encoding: ascii-8bit
#
# Signet support for bitcoin-ruby (https://github.com/lian/bitcoin-ruby).
#
# Подключение:
#
#   require 'bitcoin'
#   require 'bitcoin/signet'   # этот файл
#   Bitcoin.network = :signet
#
# Signet (BIP325) — тестовая сеть, блоки в которой подписываются «challenge»-скриптом.
# Для создания транзакций и для адресов всё устроено точно так же, как в testnet,
# поэтому гему нужен только дескриптор сети — его-то мы и добавляем ниже.
#
# Значения взяты из Bitcoin Core:
#   * src/kernel/chainparams.cpp  (class SigNetParams)
#   * src/kernel/signet.h         (SIGNET_DEFAULT_CHALLENGE)
#   * BIP325                      (https://github.com/bitcoin/bips/blob/master/bip-0325.mediawiki)

require 'digest'

module Bitcoin
  module Signet
    # "Официальный" (default) signet challenge — src/kernel/signet.h
    DEFAULT_CHALLENGE =
      "512103ad5e0edad18cb1f0fc0d28a3d4f1f3e445640337489abb10404f2d1e086be430" \
      "210359ef5021964fe22d6f8e05b2463c9540ce96883fe3b278760f048f5189f2e6c452ae".freeze

    # P2P-магия официального signet — байты на проводе: 0a 03 cf 40
    DEFAULT_MAGIC = "\x0A\x03\xCF\x40".b.freeze

    # Блок-генезис signet (одинаков для всех signet-сетей, включая кастомные)
    DEFAULT_GENESIS_HASH =
      "00000008819873e925422c1ff0f99f7cc9bbb232af63a077a480a3633bee1ef6".freeze

    module_function

    # BIP325: магия (заголовок сообщений p2p) произвольного signet — это первые
    # 4 байта от sha256d(сериализованный signet challenge), где challenge
    # сериализуется как любой скрипт/вектор в Bitcoin:
    #   CompactSize(length) || script
    #
    # Именно эта строка в Core: kernel::GetSignetMessageStart() (src/kernel/signet.h),
    # там challenge пишется в поток сериализации Bitcoin (h << signet_challenge),
    # что и даёт CompactSize-префикс.
    def magic_head(challenge_hex = DEFAULT_CHALLENGE)
      challenge  = [challenge_hex].pack("H*")
      serialized = compact_size(challenge.bytesize) + challenge
      Digest::SHA256.digest(Digest::SHA256.digest(serialized))[0, 4]
    end

    # Bitcoin CompactSize (var_int)
    def compact_size(n)
      if    n < 0xFD        then [n].pack("C")
      elsif n <= 0xFFFF     then "\xFD".b + [n].pack("v")
      elsif n <= 0xFFFFFFFF then "\xFE".b + [n].pack("V")
      else                       "\xFF".b + [n].pack("Q<")
      end
    end

    # Удобный способ добавить свой signet (bitcoind -signet -signetchallenge=...)
    # под именем +name+ (по умолчанию :signet_custom).
    def define_network!(challenge_hex, name: :signet_custom, port: 38333)
      Bitcoin::NETWORKS[name] = Bitcoin::NETWORKS[:signet].merge(
        magic_head:  magic_head(challenge_hex),
        default_port: port,
        genesis_hash: DEFAULT_GENESIS_HASH
      )
    end
  end
end

# Самопроверка: вывод формулы должен совпадать с известной магией официального signet.
unless Bitcoin::Signet.magic_head == Bitcoin::Signet::DEFAULT_MAGIC
  raise "Signet magic derivation is broken: got " \
        "#{Bitcoin::Signet.magic_head.unpack('H*').first.inspect}, " \
        "expected #{Bitcoin::Signet::DEFAULT_MAGIC.unpack('H*').first.inspect}"
end

# Дескриптор сети. Всё, что не указано явно, наследуется от :bitcoin
# (coinbase_maturity, reward_halving, retarget_interval, target_spacing,
#  max_money, min_tx_fee, dust, message_magic, protocol_version и т.д. —
#  в signet они такие же, как в mainnet).
Bitcoin::NETWORKS[:signet] ||= Bitcoin::NETWORKS[:bitcoin].merge(
  project:                   :bitcoin,
  magic_head:                Bitcoin::Signet::DEFAULT_MAGIC,
  address_version:           "6f",         # P2PKH  -> m.../n...
  p2sh_version:              "c4",         # P2SH   -> 2...
  privkey_version:           "ef",         # WIF
  extended_privkey_version:  "04358394",   # tprv
  extended_pubkey_version:   "043587cf",   # tpub
  bech32_hrp:                "tb",         # P2WPKH/P2WSH -> tb1...
  default_port:              38_333,
  bip34_height:              1,
  dns_seeds: [
    "seed.signet.bitcoin.sprovoost.nl",
    "seed.signet.achownodes.xyz",
  ],
  genesis_hash:              Bitcoin::Signet::DEFAULT_GENESIS_HASH,
  proof_of_work_limit:       0x1E0377AE,   # bits=0x1e0377ae у генезиса signet
  known_nodes:               [],
  checkpoints:               {}
)
