# frozen_string_literal: true

RSpec.describe ActionParamsContract::DryExtensions::SchemaDslPrepend do
  let(:store) { ActionParamsContract::RequestContext.store }
  let(:flag)  { ActionParamsContract::DryExtensions::ValidationScope::FLAG }

  describe "Dry::Schema::DSL.new dispatch" do
    context "when the flag is active" do
      around { |ex| ActionParamsContract::DryExtensions::ValidationScope.enabled { ex.run } }

      it "returns an instance of the gem's SchemaDsl subclass" do
        dsl = Dry::Schema::DSL.new(processor_type: Dry::Schema::Processor) do
          required(:name).filled(:string)
        end

        expect(dsl).to be_an_instance_of(ActionParamsContract::DryExtensions::SchemaDsl)
      end
    end

    context "when the flag is unset" do
      before { store[flag] = nil }

      it "returns a pristine Dry::Schema::DSL (super)" do
        dsl = Dry::Schema::DSL.new(processor_type: Dry::Schema::Processor) { required(:name).filled(:string) }

        expect(dsl).to be_an_instance_of(Dry::Schema::DSL)
      end
    end

    context "when the flag is active but the receiver is the gem's subclass" do
      around { |ex| ActionParamsContract::DryExtensions::ValidationScope.enabled { ex.run } }

      it "delegates to super (guards against recursion into SchemaDsl.new)" do
        dsl = ActionParamsContract::DryExtensions::SchemaDsl.new(processor_type: Dry::Schema::Processor) do
          required(:name).filled(:string)
        end

        expect(dsl).to be_an_instance_of(ActionParamsContract::DryExtensions::SchemaDsl)
      end
    end
  end
end
