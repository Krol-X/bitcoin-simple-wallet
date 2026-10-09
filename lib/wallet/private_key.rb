# frozen_string_literal: true

require 'fileutils'

module Wallet
  class PrivateKey
    DEFAULT_KEY_FILE = File.expand_path('../../storage/wallet.key', __dir__)

    attr_reader :value, :key_file

    def initialize(key_file = DEFAULT_KEY_FILE)
      @key_file = key_file
      @value = load_key
      return unless @value.nil?

      @value = Bitcoin::Key.generate
      save_key
    end

    def to_address
      Bitcoin.encode_segwit_address(0, @value.hash160)
    end

    def save_key
      FileUtils.mkdir_p(File.dirname(@key_file))
      tmp = "#{@key_file}.tmp"
      File.open(tmp, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |f|
        f.write("#{@value.to_base58}\n")
      end
      File.rename(tmp, @key_file)
      File.chmod(0o600, @key_file)
      nil
    end

    def inspect
      "#<PrivateKey #{@value ? @value.hash160 : 'нет ключа'} file=#{@key_file}>"
    end

    private

    def load_key
      return nil unless File.exist?(@key_file)

      wif = File.read(@key_file).strip
      return nil if wif.empty?

      File.chmod(0o600, @key_file) if (File.stat(@key_file).mode & 0o077) != 0

      Bitcoin::Key.from_base58(wif)
    rescue StandardError => e
      raise "Не удалось прочитать ключ из #{@key_file}: #{e.message}"
    end
  end
end
