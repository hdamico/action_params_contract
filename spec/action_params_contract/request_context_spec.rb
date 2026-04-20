# frozen_string_literal: true

RSpec.describe ActionParamsContract::RequestContext do
  let(:store)          { described_class.store }
  let(:action_key)     { described_class::ACTION_KEY }
  let(:controller_key) { described_class::CONTROLLER_KEY }

  describe ".around exception safety" do
    after { described_class.pop }

    it "clears the action when the block raises" do
      controller = instance_double(ApplicationController, action_name: "create")

      expect do
        described_class.around(controller) { raise "boom" }
      end.to raise_error(RuntimeError, "boom")

      expect(store[action_key]).to be_nil
    end

    it "clears the controller reference when the block raises" do
      controller = instance_double(ApplicationController, action_name: "create")

      expect do
        described_class.around(controller) { raise "boom" }
      end.to raise_error(RuntimeError, "boom")

      expect(store[controller_key]).to be_nil
    end
  end

  describe "nested .around calls" do
    after { described_class.pop }

    let(:outer_controller) { instance_double(ApplicationController, action_name: "create") }
    let(:inner_controller) { instance_double(ApplicationController, action_name: "update") }

    context "when a nested block exits cleanly" do
      it "restores the outer controller and action", :aggregate_failures do
        described_class.around(outer_controller) do
          described_class.around(inner_controller) do
            expect(described_class.current_controller).to equal(inner_controller)
          end

          expect(described_class.current_controller).to equal(outer_controller)
          expect(described_class.current_action).to eq(:create)
        end
      end
    end

    context "when the nested block raises" do
      it "still restores the outer controller and action", :aggregate_failures do
        described_class.around(outer_controller) do
          expect do
            described_class.around(inner_controller) { raise "boom" }
          end.to raise_error(RuntimeError, "boom")

          expect(described_class.current_controller).to equal(outer_controller)
          expect(described_class.current_action).to eq(:create)
        end
      end
    end
  end

  describe "IsolatedExecutionState action isolation" do
    after { store[action_key] = nil }

    it "stores and reads action from isolated storage" do
      store[action_key] = :create

      expect(store[action_key]).to eq(:create)
    end

    it "isolates action between threads", :aggregate_failures do
      store[action_key] = :create

      thread_value = Thread.new { store[action_key] }.value

      expect(thread_value).to be_nil
      expect(store[action_key]).to eq(:create)
    end

    it "does not leak state between sequential operations" do
      store[action_key] = :create
      store[action_key] = nil

      expect(store[action_key]).to be_nil
    end
  end

  describe "Concurrent contract building" do
    before do
      stub_const("ActionParamsContract::Contracts::ConcurrentTestSchema", Module.new)

      ActionParamsContract::ContractGenerator.call("ConcurrentTestSchema") do
        params do
          required(:name).filled(:string)
        end
      end
    end

    it "builds independent contract classes across threads", :aggregate_failures do
      contracts = Array.new(5) do
        Thread.new { ActionParamsContract::Contracts::ConcurrentTestSchema.build_contract }
      end.map(&:value)

      expect(contracts.uniq(&:object_id).size).to eq(5)
      expect(contracts).to all(be < Dry::Validation::Contract)
    end

    it "validates correctly across concurrent threads", :aggregate_failures do
      results = Array.new(10) do |index|
        Thread.new do
          contract_class = ActionParamsContract::Contracts::ConcurrentTestSchema.build_contract
          input = index.even? ? { name: "Alice" } : { name: "" }
          contract_class.new.call(input)
        end
      end.map(&:value)

      successes, failures = results.partition(&:success?)

      expect(successes.size).to eq(5)
      expect(failures.size).to eq(5)
    end
  end

  describe "Concurrent action-conditional validation" do
    before do
      stub_const("ActionParamsContract::Contracts::ActionThreadTestSchema", Module.new)

      ActionParamsContract::ContractGenerator.call("ActionThreadTestSchema") do
        params do
          on_create { required(:title).filled(:string) }
          on_update { required(:id).filled(:integer) }
        end
      end
    end

    after { store[action_key] = nil }

    def run_action_conditional_thread(index)
      Thread.new do
        action = index.even? ? :create : :update
        store[action_key] = action

        result = ActionParamsContract::DryExtensions::ValidationScope.enabled do
          contract_class = ActionParamsContract::Contracts::ActionThreadTestSchema.build_contract
          input = index.even? ? { title: "Post" } : { "id" => 1 }
          contract_class.new.call(input)
        end

        { action:, success: result.success? }
      ensure
        store[action_key] = nil
      end
    end

    it "applies correct action-conditional rules per thread", :aggregate_failures do
      results = Array.new(10) { |index| run_action_conditional_thread(index) }.map(&:value)

      create_results = results.select { |result| result[:action] == :create }
      update_results = results.select { |result| result[:action] == :update }

      expect(create_results).to all(include(success: true))
      expect(update_results).to all(include(success: true))
    end
  end

  describe "Concurrent root :key evaluation" do
    let(:root_key)     { described_class::ROOT_KEY }
    let(:thread_count) { 5 }

    before do
      thread_count.times do |index|
        stub_const("ActionParamsContract::Contracts::ConcurrentRootSchema#{index}", Module.new)

        ActionParamsContract::ContractGenerator.call("ConcurrentRootSchema#{index}") do
          params do
            root :"object_#{index}"
            optional(:ignored).maybe(:string)
          end
        end
      end
    end

    after { store[root_key] = nil }

    def run_root_evaluation_thread(index, barrier)
      Thread.new do
        barrier.pop
        ActionParamsContract::DryExtensions::ValidationScope.enabled do
          ActionParamsContract::Contracts.const_get(:"ConcurrentRootSchema#{index}", false).build_contract
        end
        { index:, root: store[root_key] }
      ensure
        store[root_key] = nil
      end
    end

    it "isolates root :key per thread with no cross-pollution" do
      barrier = Queue.new
      thread_count.times { barrier << :go }

      results = Array.new(thread_count) { |index| run_root_evaluation_thread(index, barrier) }.map(&:value)

      expect(results).to match_array(Array.new(thread_count) { |i| { index: i, root: :"object_#{i}" } })
    end
  end
end
