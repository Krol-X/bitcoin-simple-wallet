# frozen_string_literal: true

require_relative "lib/bitcoin_simple_wallet/version"

Gem::Specification.new do |spec|
  spec.name = "bitcoin_simple_wallet"
  spec.version = BitcoinSimpleWallet::VERSION
  spec.authors = ["Alex Krol"]
  spec.email = ["krolmail@list.ru"]

  spec.summary = "A minimal Bitcoin signet wallet for the command line, with one-shot commands and an interactive mode"
  spec.homepage = "https://github.com/Krol-X/bitcoin-simple-wallet"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  # spec.metadata["allowed_push_host"] = ""
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Krol-X/bitcoin-simple-wallet"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "bitcoinrb", "~> 1.15"
  spec.add_dependency "zeitwerk", "~> 2.8"
end
