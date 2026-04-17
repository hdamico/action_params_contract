# frozen_string_literal: true

RSpec.describe ActionParamsContract::ContractGenerator do
  before do
    stub_const("ActionParamsContract::Contracts::TestContractSchema", Module.new)
    stub_const("ActionParamsContract::Contracts::AnotherContractSchema", Module.new)
  end

  describe ".call" do
    it "registers a module with schema_block and build_contract", :aggregate_failures do
      result = described_class.call("TestContractSchema") do
        params do
          required(:name).filled(:string)
        end
      end

      expect(result).to respond_to(:schema_block)
      expect(result).to respond_to(:build_contract)
    end

    it "returns a callable schema_block" do
      described_class.call("TestContractSchema") do
        params do
          required(:name).filled(:string)
        end
      end

      expect(ActionParamsContract::Contracts::TestContractSchema.schema_block).to be_a(Proc)
    end

    it "reuses existing module when called twice with same name" do
      described_class.call("TestContractSchema") do
        params do
          required(:name).filled(:string)
        end
      end

      mod = ActionParamsContract::Contracts::TestContractSchema

      described_class.call("TestContractSchema") do
        params do
          required(:email).filled(:string)
        end
      end

      expect(ActionParamsContract::Contracts::TestContractSchema).to equal(mod)
    end

    it "uses the latest block when the same name is registered twice" do
      described_class.call("TestContractSchema") do
        params do
          required(:first_field).filled(:string)
        end
      end

      described_class.call("TestContractSchema") do
        params do
          required(:second_field).filled(:string)
        end
      end

      errors = ActionParamsContract::Contracts::TestContractSchema.build_contract.new.call({}).errors.to_h

      expect(errors.keys).to contain_exactly(:second_field)
    end

    it "does not leak the registered constant to the top-level namespace" do
      described_class.call("TestContractSchema") do
        params { required(:name).filled(:string) }
      end

      expect(Object.const_defined?(:TestContractSchema, false)).to be(false)
    end
  end

  describe "concurrent registration" do
    let(:thread_count) { 10 }

    before { stub_const("ActionParamsContract::Contracts::RaceContractSchema", Module.new) }

    context "when many threads call .call on the same fresh schema name simultaneously" do
      it "yields a single, consistent, usable schema constant", :aggregate_failures do
        barrier = Queue.new
        thread_count.times { barrier << :go }

        threads = Array.new(thread_count) do
          Thread.new do
            barrier.pop
            described_class.call("RaceContractSchema") do
              params { required(:n).filled(:integer) }
            end
          end
        end
        threads.each(&:join)

        result = ActionParamsContract::Contracts::RaceContractSchema.build_contract.new.call(n: 1)

        expect(result).to be_success
        expect(result.to_h).to eq(n: 1)
      end
    end
  end

  describe ".build_contract" do
    before do
      described_class.call("TestContractSchema") do
        params do
          required(:name).filled(:string)
        end
      end
    end

    it "returns a fresh contract class each call", :aggregate_failures do
      contract_a = ActionParamsContract::Contracts::TestContractSchema.build_contract
      contract_b = ActionParamsContract::Contracts::TestContractSchema.build_contract

      expect(contract_a).not_to equal(contract_b)
      expect(contract_a).to be < Dry::Validation::Contract
      expect(contract_b).to be < Dry::Validation::Contract
    end

    it "builds a working contract that validates params", :aggregate_failures do
      contract_class = ActionParamsContract::Contracts::TestContractSchema.build_contract
      result = contract_class.new.call(name: "Alice")

      expect(result).to be_success
      expect(result.to_h).to eq(name: "Alice")
    end

    it "builds a contract that reports errors for invalid params", :aggregate_failures do
      contract_class = ActionParamsContract::Contracts::TestContractSchema.build_contract
      result = contract_class.new.call(name: "")

      expect(result).to be_failure
      expect(result.errors.to_h).to have_key(:name)
    end
  end
end
