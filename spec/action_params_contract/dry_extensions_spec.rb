# frozen_string_literal: true

RSpec.describe ActionParamsContract::DryExtensions do
  around do |example|
    ActionParamsContract::DryExtensions::ValidationScope.enabled { example.run }
  end

  describe "default macro with falsy values" do
    before do
      stub_const("ActionParamsContract::Contracts::DefaultFalsySchema", Module.new)

      ActionParamsContract::ContractGenerator.call("DefaultFalsySchema") do
        params do
          optional(:flag).maybe(:bool).default(true)
        end
      end
    end

    context "when the incoming value is explicitly false" do
      subject(:result) { ActionParamsContract::Contracts::DefaultFalsySchema.build_contract.new.call(flag: false) }

      it "respects the user-provided false instead of overriding with the default" do
        expect(result.to_h).to eq(flag: false)
      end
    end

    context "when the value is omitted" do
      subject(:result) { ActionParamsContract::Contracts::DefaultFalsySchema.build_contract.new.call({}) }

      it "fills in the default" do
        expect(result.to_h).to eq(flag: true)
      end
    end

    context "when the incoming value is a truthy non-default" do
      subject(:result) { ActionParamsContract::Contracts::DefaultFalsySchema.build_contract.new.call(flag: true) }

      it "leaves the provided value untouched" do
        expect(result.to_h).to eq(flag: true)
      end
    end
  end

  describe "default macro with a mutable Array value" do
    before do
      stub_const("ActionParamsContract::Contracts::DefaultMutableSchema", Module.new)

      ActionParamsContract::ContractGenerator.call("DefaultMutableSchema") do
        params do
          optional(:tags).filled(:array).default([])
        end
      end
    end

    context "when one request mutates the resulting array in place" do
      it "does not leak the mutation into a subsequent request" do
        first  = ActionParamsContract::Contracts::DefaultMutableSchema.build_contract.new.call({}).to_h
        first[:tags] << "leaked"

        second = ActionParamsContract::Contracts::DefaultMutableSchema.build_contract.new.call({}).to_h

        expect(second[:tags]).to eq([])
      end
    end
  end

  describe "default macro with a Proc value" do
    before do
      stub_const("ActionParamsContract::Contracts::DefaultProcSchema", Module.new)
      stub_const("ActionParamsContract::Contracts::DefaultCounterSchema", Module.new)

      ActionParamsContract::ContractGenerator.call("DefaultProcSchema") do
        params do
          optional(:starts_at).maybe(:time).default(-> { Time.utc(2026, 4, 16) })
        end
      end

      counter = 0
      ActionParamsContract::ContractGenerator.call("DefaultCounterSchema") do
        params do
          optional(:n).filled(:integer).default(-> { counter += 1 })
        end
      end
    end

    context "when the value is omitted and the default is a Proc" do
      it "stores the resolved value, not the Proc literal" do
        result = ActionParamsContract::Contracts::DefaultProcSchema.build_contract.new.call({}).to_h

        expect(result[:starts_at]).to eq(Time.utc(2026, 4, 16))
      end
    end

    context "when the Proc returns a fresh value on each call" do
      it "evaluates the Proc per request" do
        first  = ActionParamsContract::Contracts::DefaultCounterSchema.build_contract.new.call({}).to_h
        second = ActionParamsContract::Contracts::DefaultCounterSchema.build_contract.new.call({}).to_h

        expect([first[:n], second[:n]]).to eq([1, 2])
      end
    end
  end

  describe "default macro chained on a required key" do
    before { stub_const("ActionParamsContract::Contracts::DefaultOnRequiredSchema", Module.new) }

    context "when the schema declares required(:x).filled(...).default(y)" do
      it "raises ArgumentError pointing at the neutralisation problem" do
        ActionParamsContract::ContractGenerator.call("DefaultOnRequiredSchema") do
          params do
            required(:page).filled(:integer).default(1)
          end
        end

        expect { ActionParamsContract::Contracts::DefaultOnRequiredSchema.build_contract }
          .to raise_error(ArgumentError, /neutralising required/)
      end
    end
  end

  describe ActionParamsContract::DryExtensions::ControllerActionDsl do
    let(:evaluator_klass) do
      Class.new do
        include ActionParamsContract::DryExtensions::ControllerActionDsl

        def current_action?(_action) = true
      end
    end
    let(:evaluator) { evaluator_klass.new }

    describe "#on_action without a block" do
      it "is a no-op" do
        expect { evaluator.on_action(:create) }.not_to raise_error
      end
    end

    describe "#on_actions without a block" do
      it "is a no-op across every action name" do
        expect { evaluator.on_actions(:create, :update, :destroy) }.not_to raise_error
      end
    end
  end

  describe "current_action? without thread-local context" do
    after { ActionParamsContract::RequestContext.store[ActionParamsContract::RequestContext::ACTION_KEY] = nil }

    before do
      stub_const("ActionParamsContract::Contracts::ActionContextSchema", Module.new)
      ActionParamsContract::RequestContext.store[ActionParamsContract::RequestContext::ACTION_KEY] = nil

      ActionParamsContract::ContractGenerator.call("ActionContextSchema") do
        params do
          required(:title).filled(:string)
          on_create { required(:slug).filled(:string) }
        end

        rule(:title) do
          key.failure("rule fired") if current_action?(:create)
        end
      end
    end

    context "when invoked from a SchemaDsl-wrapped block (on_create inside params)" do
      it "skips the on_create branch (no thread-local action set)" do
        result = ActionParamsContract::Contracts::ActionContextSchema.build_contract.new.call(title: "ok")

        expect(result.errors.to_h.keys).not_to include(:slug)
      end
    end

    context "when invoked from an Evaluator-wrapped block (rule body)" do
      it "skips the rule body (consistent with SchemaDsl policy)" do
        result = ActionParamsContract::Contracts::ActionContextSchema.build_contract.new.call(title: "ok")

        expect(result.errors.to_h.keys).not_to include(:title)
      end
    end
  end

  describe "root DSL with duplicate declarations" do
    let(:controller) { Object.new }

    before do
      stub_const("ActionParamsContract::Contracts::DuplicateRootSchema", Module.new)
      ActionParamsContract::RequestContext.store[ActionParamsContract::RequestContext::CONTROLLER_KEY] = controller
    end

    after { ActionParamsContract::RequestContext.store[ActionParamsContract::RequestContext::CONTROLLER_KEY] = nil }

    context "when the same key is declared twice" do
      it "is a no-op (idempotent)" do
        ActionParamsContract::ContractGenerator.call("DuplicateRootSchema") do
          params do
            root :article
            root :article
            optional(:anything).maybe(:string)
          end
        end

        expect { ActionParamsContract::Contracts::DuplicateRootSchema.build_contract }.not_to raise_error
      end
    end

    context "when two distinct keys are declared" do
      it "raises ArgumentError pointing at the conflict" do
        ActionParamsContract::ContractGenerator.call("DuplicateRootSchema") do
          params do
            root :article
            root :post
            optional(:anything).maybe(:string)
          end
        end

        expect { ActionParamsContract::Contracts::DuplicateRootSchema.build_contract }
          .to raise_error(ArgumentError, /root :article already declared/)
      end
    end
  end

  describe "root DSL when no controller is in thread-local storage" do
    before do
      stub_const("ActionParamsContract::Contracts::RootNoControllerSchema", Module.new)
      ActionParamsContract::RequestContext.store[ActionParamsContract::RequestContext::CONTROLLER_KEY] = nil

      ActionParamsContract::ContractGenerator.call("RootNoControllerSchema") do
        params do
          root :ignored
          optional(:anything).maybe(:string)
        end
      end
    end

    after do
      ActionParamsContract::RequestContext.store[ActionParamsContract::RequestContext::CONTROLLER_KEY] = nil
    end

    it "silently no-ops rather than raising a NoMethodError on nil" do
      expect { ActionParamsContract::Contracts::RootNoControllerSchema.build_contract }.not_to raise_error
    end
  end
end
