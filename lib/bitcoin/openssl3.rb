# encoding: ascii-8bit
#
# Патч совместимости bitcoin-ruby 0.0.20 с OpenSSL 3.x (Ruby >= 3.1).
#
#   require 'stringio'
#   require 'bitcoin'
#   require 'bitcoin/openssl3'   # этот файл
#
# Зачем: в OpenSSL 3 объекты OpenSSL::PKey::EC стали immutable, и старый API,
# на который опирается bitcoin-ruby, больше не работает:
#
#   Bitcoin::Key.generate
#   # => OpenSSL::PKey::PKeyError: pkeys are immutable on OpenSSL 3.0
#
# Падает всё, где гем делает `key.private_key = ...`, `key.public_key = ...`,
# `key.generate_key` или `Point.from_hex`. Без этого патча на современном Ruby
# (3.1+, OpenSSL 3) нельзя ни сгенерировать ключ, ни импортировать WIF,
# ни подписать/проверить транзакцию.
#
# Решение: собирать EC-ключи из ASN.1/DER (SEC1 для приватного, SPKI для
# публичного) и отдавать в OpenSSL::PKey::EC.new(der) — такие ключи «только для
# чтения», но полностью рабочие для подписи и проверки. Официально
# рекомендованный обходной путь (см. ruby/openssl#498).
#
# Кроме этого тут учтены ещё три несовместимости OpenSSL 1.1 -> 3 для этого гема:
#   * EC_POINT_bn2point больше не подставляет префикс 0x04 к «голым» координатам
#     X||Y (гем так импортировал публичные ключи, см. ContractHash);
#   * dsa_verify_asn1 вместо false теперь может бросить PKeyError
#     ("provider signature failure") на мусорных подписях;
#   * d2i_ECDSA_SIG в FFI-хелпере падал с SIGSEGV на невалидном DER —
#     нормализация подписи сделана без FFI-указателей.

require 'openssl'
require 'securerandom'

module Bitcoin
  # Хелперы для работы с secp256k1-ключами без мутации OpenSSL-объектов.
  module ECKey
    CURVE = "secp256k1".freeze

    module_function

    def group
      @group ||= OpenSSL::PKey::EC::Group.new(CURVE)
    end

    # point -> hex (compressed / uncompressed), 33 или 65 байт
    def point_hex(point, compressed = true)
      point.to_octet_string(compressed ? :compressed : :uncompressed).unpack("H*")[0]
    end

    # приватный ключ (hex) -> OpenSSL::PKey::EC с приватным и публичным ключом
    def key_from_priv(priv_hex)
      key_from_priv_octets(OpenSSL::BN.new(priv_hex, 16), nil)
    end

    # приватный ключ (OpenSSL::BN) + публичный (hex) -> OpenSSL::PKey::EC
    def key_from_priv_and_pub(priv_bn, pub_hex)
      key_from_priv_octets(priv_bn, point_from_hex(pub_hex).to_octet_string(:uncompressed))
    end

    def key_from_priv_octets(priv_bn, pub_octets)
      pub_octets ||= group.generator.mul(priv_bn).to_octet_string(:uncompressed)
      der = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Integer(1),
        OpenSSL::ASN1::OctetString(priv_bn.to_s(2).rjust(32, "\x00")),
        OpenSSL::ASN1::ObjectId(CURVE, 0, :EXPLICIT),
        OpenSSL::ASN1::BitString(pub_octets, 1, :EXPLICIT)
      ]).to_der
      OpenSSL::PKey::EC.new(der)
    end

    # публичный ключ (hex) -> OpenSSL::PKey::EC (только публичная часть)
    def key_from_pub(pub_hex)
      point = point_from_hex(pub_hex)
      key_from_point(point, ["02", "03"].include?(pub_hex[0, 2]))
    end

    def key_from_point(point, compressed = true)
      octets = point.to_octet_string(compressed ? :compressed : :uncompressed)
      spki = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Sequence([
          OpenSSL::ASN1::ObjectId("id-ecPublicKey"),
          OpenSSL::ASN1::ObjectId(CURVE)
        ]),
        OpenSSL::ASN1::BitString(octets)
      ]).to_der
      OpenSSL::PKey::EC.new(spki)
    end

    # Аналог старого OpenSSL::PKey::EC::Point.from_hex (EC_POINT_bn2point).
    #
    # В OpenSSL <= 1.1 гем передавал сюда «сырой» BIGNUM, и OpenSSL сам
    # додумывал формат: для 64-байтовой строки X||Y подставлялся префикс 0x04
    # (несжатая точка). В OpenSSL 3 такого больше нет, поэтому делаем это сами.
    # Классы ошибок оставлены те же (BNError / Point::Error) — на них в геме
    # уже есть rescue в Bitcoin.verify_signature.
    def point_from_hex(pub_hex)
      bytes = OpenSSL::BN.new(pub_hex, 16).to_s(2)
      if bytes.bytesize == 64
        bytes = "\x04".b + bytes
      end
      if bytes.bytesize < 2
        raise OpenSSL::PKey::EC::Point::Error, "invalid public key encoding"
      end
      OpenSSL::PKey::EC::Point.new(group, OpenSSL::BN.new(bytes.unpack("H*")[0], 16))
    end

    # случайный приватный ключ в допустимом диапазоне, hex (64 символа)
    def random_priv_hex
      loop do
        priv = SecureRandom.hex(32)
        value = priv.to_i(16)
        return priv if value > 0 && value < Bitcoin::CURVE_ORDER
      end
    end
  end
end

module Bitcoin
  class Key
    # Замена Bitcoin::Key.generate (в оригинале @key.generate_key)
    def generate
      @key = Bitcoin::ECKey.key_from_priv(Bitcoin::ECKey.random_priv_hex)
    end

    # 33-байтовое сжатое представление (66 hex)
    def pub_compressed
      Bitcoin::ECKey.point_hex(@key.public_key, true)
    end

    # 65-байтовое несжатое представление (130 hex)
    def pub_uncompressed
      Bitcoin::ECKey.point_hex(@key.public_key, false)
    end

    # Проверка подписи: в OpenSSL 3 dsa_verify_asn1 может бросить PKeyError
    # ("provider signature failure") вместо того, чтобы вернуть false.
    def verify(data, sig)
      regenerate_pubkey unless @key.public_key
      sig = Bitcoin::OpenSSL_EC.repack_der_signature(sig)
      if sig
        @key.dsa_verify_asn1(data, sig)
      else
        false
      end
    rescue OpenSSL::PKey::PKeyError, OpenSSL::PKey::EC::Point::Error, OpenSSL::BNError
      false
    end

    protected

    # Регенерировать публичный ключ из приватного.
    def regenerate_pubkey
      return nil unless @key.private_key
      set_priv(priv)
    end

    def set_priv(priv)
      value = priv.to_i(16)
      unless MIN_PRIV_KEY_MOD_ORDER <= value && value <= MAX_PRIV_KEY_MOD_ORDER
        raise 'private key is not on curve'
      end
      @key = Bitcoin::ECKey.key_from_priv(priv)
    end

    def set_pub(pub, compressed = nil)
      @pubkey_compressed = compressed.nil? ? self.class.is_compressed_pubkey?(pub) : compressed
      # если приватный ключ уже известен — сохраняем его (Key#pub= не должен его терять)
      priv_hex = (@key.private_key ? self.priv : nil)
      @key = if priv_hex
               Bitcoin::ECKey.key_from_priv_and_pub(OpenSSL::BN.new(priv_hex, 16), pub)
             else
               Bitcoin::ECKey.key_from_pub(pub)
             end
    end
  end
end

module Bitcoin
  class << self
    # [priv_hex, pub_hex] — как OpenSSL::PKey::EC#private_key_hex / #public_key_hex
    def generate_key
      priv_hex = Bitcoin::ECKey.random_priv_hex
      pub_hex  = Bitcoin::ECKey.point_hex(
        Bitcoin::ECKey.group.generator.mul(OpenSSL::BN.new(priv_hex, 16)), false
      )
      [priv_hex, pub_hex]
    end

    def verify_signature(hash, signature, public_key)
      key = Bitcoin::ECKey.key_from_pub(public_key)
      signature = Bitcoin::OpenSSL_EC.repack_der_signature(signature)
      return false unless signature
      key.dsa_verify_asn1(hash, signature)
    rescue OpenSSL::PKey::PKeyError, OpenSSL::PKey::EC::Point::Error, OpenSSL::BNError
      false
    end

    # Оригинал мутировал key.private_key= / key.public_key=, что в OpenSSL 3
    # запрещено. Поведение прежнее: без public_key публичный ключ выводится из
    # приватного (в несжатом виде, как делал OpenSSL_EC.regenerate_key).
    def open_key(private_key, public_key = nil)
      priv_bn = OpenSSL::BN.new(private_key, 16)
      octets = if public_key
                 Bitcoin::ECKey.point_from_hex(public_key).to_octet_string(:uncompressed)
               else
                 Bitcoin::ECKey.group.generator.mul(priv_bn).to_octet_string(:uncompressed)
               end
      Bitcoin::ECKey.key_from_priv_octets(priv_bn, octets)
    end
  end

  module OpenSSL_EC
    class << self
      # Безопасная замена FFI-версии repack_der_signature.
      #
      # Оригинал делает d2i_ECDSA_SIG -> i2d_ECDSA_SIG через FFI. Тут две
      # проблемы: (1) на невалидном DER d2i возвращает NULL, а i2d с NULL
      # роняет процесс SIGSEGV (спастись rescue нельзя); (2) на Ruby 4.0
      # старый FFI-код просто не проходит. Здесь нормализация DER сделана
      # средствами OpenSSL::ASN1.
      #
      # Семантика как у d2i_ECDSA_SIG:
      #  * DER читается с начала строки, «хвост» после подписи игнорируется
      #    (гем так передаёт sig + байт sighash);
      #  * числа r/s читаются как беззнаковые: ASN1_INTEGER_to_BN отбрасывает
      #    знаковый бит, поэтому «негативные» r/s из старых неканоничных
      #    подписей проверялись успешно (это поведение зафиксировано в
      #    примерах BIP66: example 1/2/7/8 ожидаются истинными).
      def repack_der_signature(signature)
        return false if signature.nil? || signature.empty?

        r, s = parse_der_signature(signature)
        return false unless r && s

        OpenSSL::ASN1::Sequence([
          OpenSSL::ASN1::Integer(OpenSSL::BN.new(r.unpack("H*")[0], 16)),
          OpenSSL::ASN1::Integer(OpenSSL::BN.new(s.unpack("H*")[0], 16))
        ]).to_der
      rescue OpenSSL::ASN1::ASN1Error, OpenSSL::ASN1::TypeError, ArgumentError
        false
      end

      # raw DER -> [r_bytes, s_bytes] или nil, если это не SEQUENCE из двух INTEGER
      def parse_der_signature(sig)
        return nil unless sig.getbyte(0) == 0x30

        seq_len, pos = der_length(sig, 1)
        return nil unless seq_len && pos + seq_len <= sig.bytesize

        r, pos = der_integer(sig, pos)
        return nil unless r
        s, = der_integer(sig, pos)
        return nil unless s

        [r, s]
      end

      def der_length(sig, pos)
        return nil if pos >= sig.bytesize
        len = sig.getbyte(pos)
        pos += 1
        if (len & 0x80) != 0
          nbytes = len & 0x7f
          return nil if nbytes.zero? || nbytes > 4 || pos + nbytes > sig.bytesize
          len = 0
          nbytes.times { len = (len << 8) | sig.getbyte(pos); pos += 1 }
        end
        [len, pos]
      end

      def der_integer(sig, pos)
        return [nil, pos] if pos >= sig.bytesize || sig.getbyte(pos) != 0x02
        len, pos = der_length(sig, pos + 1)
        return [nil, pos] unless len && pos + len <= sig.bytesize
        [sig.byteslice(pos, len), pos + len]
      end

      # FFI-версия regenerate_key тоже мутировала ключ через Ruby-биндинги.
      def regenerate_key(private_key)
        private_key = [private_key].pack('H*') if private_key.bytesize >= (32 * 2)
        priv_hex = private_key.unpack('H*')[0]
        key = Bitcoin::ECKey.key_from_priv(priv_hex)
        if key.private_key.to_i != priv_hex.to_i(16)
          raise 'regenerated wrong private_key, raise here before generating a faulty public_key too!'
        end
        [priv_hex, Bitcoin::ECKey.point_hex(key.public_key, false)]
      end
    end
  end

  # ExtPubkey#pub получал сжатый ключ через группу; на OpenSSL 3 to_bn всегда
  # отдаёт несжатые координаты, поэтому берём байты точки напрямую.
  class ExtPubkey
    def pub
      Bitcoin::ECKey.point_hex(pub_key, true)
    end
  end
end

# Утилиты, добавленные самим гемом: они тоже опирались на mutable-состояние
# группы через Point#to_bn.
module OpenSSL
  class PKey::EC
    def private_key_hex
      private_key.to_i.to_s(16).rjust(64, '0')
    end

    def public_key_hex
      public_key.to_octet_string(:uncompressed).unpack('H*')[0]
    end

    def pubkey_compressed?
      public_key.to_octet_string(:compressed).bytesize == 33
    end
  end

  class PKey::EC::Point
    def to_hex
      to_octet_string(:uncompressed).unpack('H*')[0]
    end
  end
end
