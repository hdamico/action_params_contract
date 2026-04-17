# frozen_string_literal: true

RSpec.describe ActionParamsContract::Configuration do
  subject(:configuration) { described_class.new }

  describe "#whitelisted_params" do
    context "when freshly initialized" do
      it "defaults to the framework whitelist" do
        expect(configuration.whitelisted_params).to eq(%i[format controller action locale])
      end

      it "exposes a mutable dup rather than the frozen constant" do
        expect(configuration.whitelisted_params).not_to be_frozen
      end
    end

    context "when the dup is mutated in place" do
      it "does not leak back into DEFAULT_WHITELISTED_PARAMS" do
        configuration.whitelisted_params << :tenant

        expect(described_class::DEFAULT_WHITELISTED_PARAMS).to eq(%i[format controller action locale])
      end
    end
  end
end
