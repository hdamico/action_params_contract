# frozen_string_literal: true

RSpec.describe ActionParamsContract::InvalidParamsError do
  describe "#initialize" do
    context "without an errors argument" do
      subject(:error) { described_class.new }

      it "defaults errors to an empty hash and sets the canonical message" do
        expect(error).to have_attributes(errors: {}, message: "Params failed validation")
      end
    end

    context "with an errors hash" do
      subject(:error) { described_class.new(name: ["is missing"]) }

      it "exposes the errors and sets the canonical message" do
        expect(error).to have_attributes(
          errors: { name: ["is missing"] },
          message: "Params failed validation"
        )
      end
    end
  end

  it "descends from StandardError so controllers can rescue_from it" do
    expect(described_class).to be < StandardError
  end
end
