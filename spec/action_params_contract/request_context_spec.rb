# frozen_string_literal: true

RSpec.describe ActionParamsContract::RequestContext do
  let(:store)          { described_class.store }
  let(:action_key)     { described_class::ACTION_KEY }
  let(:controller_key) { described_class::CONTROLLER_KEY }

  describe ".around" do
    after { described_class.pop }

    context "when the block raises" do
      it "clears the action" do
        controller = instance_double(ApplicationController, action_name: "create")

        expect do
          described_class.around(controller) { raise "boom" }
        end.to raise_error(RuntimeError, "boom")

        expect(store[action_key]).to be_nil
      end

      it "clears the controller reference" do
        controller = instance_double(ApplicationController, action_name: "create")

        expect do
          described_class.around(controller) { raise "boom" }
        end.to raise_error(RuntimeError, "boom")

        expect(store[controller_key]).to be_nil
      end
    end

    context "when nested .around blocks exit cleanly" do
      let(:outer_controller) { instance_double(ApplicationController, action_name: "create") }
      let(:inner_controller) { instance_double(ApplicationController, action_name: "update") }

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

    context "when a nested .around block raises" do
      let(:outer_controller) { instance_double(ApplicationController, action_name: "create") }
      let(:inner_controller) { instance_double(ApplicationController, action_name: "update") }

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

  describe ".store" do
    after { store[action_key] = nil }

    context "when writing and reading the action key" do
      it "stores and reads action from isolated storage" do
        store[action_key] = :create

        expect(store[action_key]).to eq(:create)
      end
    end

    context "when accessed from a different thread" do
      it "isolates action between threads", :aggregate_failures do
        store[action_key] = :create

        thread_value = Thread.new { store[action_key] }.value

        expect(thread_value).to be_nil
        expect(store[action_key]).to eq(:create)
      end
    end

    context "when the action key is cleared" do
      it "does not leak state between sequential operations" do
        store[action_key] = :create
        store[action_key] = nil

        expect(store[action_key]).to be_nil
      end
    end
  end

  describe ".build_contract concurrency" do
    before do
      stub_const("ActionParamsContract::Contracts::ConcurrentTestSchema", Module.new)

      ActionParamsContract::ContractGenerator.call("ConcurrentTestSchema") do
        params do
          required(:name).filled(:string)
        end
      end
    end

    context "when invoked concurrently from multiple threads" do
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
  end

  describe ".build_contract action-conditional concurrency" do
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

    context "when threads set different actions concurrently" do
      it "applies correct action-conditional rules per thread", :aggregate_failures do
        results = Array.new(10) { |index| run_action_conditional_thread(index) }.map(&:value)

        create_results = results.select { |result| result[:action] == :create }
        update_results = results.select { |result| result[:action] == :update }

        expect(create_results).to all(include(success: true))
        expect(update_results).to all(include(success: true))
      end
    end
  end

  describe ".around reentrant Params.cast" do
    let(:thread_count) { 8 }

    before do
      stub_const("ReentrantOuterController", Class.new { def self.name = "ReentrantOuterController" })
      stub_const("ReentrantInnerController", Class.new { def self.name = "ReentrantInnerController" })

      stub_const("ActionParamsContract::Contracts::ReentrantOuterControllerSchema", Module.new)
      stub_const("ActionParamsContract::Contracts::ReentrantInnerControllerSchema", Module.new)

      ActionParamsContract::ContractGenerator.call("ReentrantOuterControllerSchema") do
        params { required(:name).filled(:string) }
      end

      ActionParamsContract::ContractGenerator.call("ReentrantInnerControllerSchema") do
        params { required(:code).filled(:integer) }
      end
    end

    def outer_controller_instance
      ReentrantOuterController.new.tap do |instance|
        instance.define_singleton_method(:action_name) { "create" }
      end
    end

    def run_reentrant_thread(index, barrier)
      Thread.new do
        described_class.around(outer_controller_instance) do
          barrier.pop
          outer = ActionParamsContract::Params.cast({ name: "outer-#{index}" })
          inner = ActionParamsContract::Params.cast(
            { code: index.to_s }, controller: ReentrantInnerController, action: :create
          )
          {
            outer_name: outer["name"], inner_code: inner["code"],
            controller_after: described_class.current_controller&.class,
            action_after: described_class.current_action,
          }
        end
      end
    end

    context "when a nested Params.cast runs inside a concurrent outer .around frame" do
      it "preserves each thread's outer frame across a nested Params.cast call" do
        barrier = Queue.new
        thread_count.times { barrier << :go }

        results = Array.new(thread_count) { |index| run_reentrant_thread(index, barrier) }.map(&:value)

        expected = Array.new(thread_count) do |i|
          {
            outer_name: "outer-#{i}",
            inner_code: i,
            controller_after: ReentrantOuterController,
            action_after: :create,
          }
        end

        expect(results).to match_array(expected)
      end
    end
  end
end
