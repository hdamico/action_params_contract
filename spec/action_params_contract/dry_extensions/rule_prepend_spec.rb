# frozen_string_literal: true

RSpec.describe ActionParamsContract::DryExtensions::RulePrepend do
  let(:store) { ActionParamsContract::RequestContext.store }
  let(:flag)  { ActionParamsContract::DryExtensions::ValidationScope::FLAG }

  describe "Rule#call dispatch" do
    let(:captured) { [] }
    let(:contract_class) do
      sink = captured

      Class.new(Dry::Validation::Contract) do
        params { required(:name).filled(:string) }

        rule(:name) do
          sink << self.class
        end
      end
    end

    context "when the flag is active" do
      around { |ex| ActionParamsContract::DryExtensions::ValidationScope.enabled { ex.run } }

      it "instantiates the gem's Evaluator subclass for the rule block" do
        contract_class.new.call(name: "Alice")

        expect(captured.first).to be(ActionParamsContract::DryExtensions::Evaluator)
      end
    end

    context "when the flag is unset" do
      before { store[flag] = nil }

      it "instantiates a pristine Dry::Validation::Evaluator (super)" do
        contract_class.new.call(name: "Alice")

        expect(captured.first).to be(Dry::Validation::Evaluator)
      end
    end
  end
end
