# frozen_string_literal: true

RSpec.describe BitcoinSimpleWallet do
  it "has a version number" do
    expect(BitcoinSimpleWallet::VERSION).not_to be_nil
  end

  it "eager loads all constants" do
    expect { Zeitwerk::Loader.eager_load_all }.not_to raise_error
  end
end
