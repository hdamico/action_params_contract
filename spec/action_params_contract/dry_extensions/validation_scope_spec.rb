# frozen_string_literal: true

RSpec.describe ActionParamsContract::DryExtensions::ValidationScope do
  let(:store) { ActionParamsContract::RequestContext.store }
  let(:flag)  { described_class::FLAG }

  after { store[flag] = nil }

  describe ".active?" do
    context "when the flag is unset" do
      before { store[flag] = nil }

      it "returns false" do
        expect(described_class.active?).to be(false)
      end
    end

    context "when the flag is truthy" do
      before { store[flag] = true }

      it "returns true" do
        expect(described_class.active?).to be(true)
      end
    end
  end

  describe ".enabled" do
    context "with a previous flag value set" do
      before { store[flag] = "previous-value" }

      it "restores the previous value after the block" do
        described_class.enabled { nil }

        expect(store[flag]).to eq("previous-value")
      end
    end

    context "when the block raises" do
      it "still clears the flag", :aggregate_failures do
        expect { described_class.enabled { raise "boom" } }.to raise_error(RuntimeError, "boom")
        expect(store[flag]).to be_nil
      end
    end
  end
end
