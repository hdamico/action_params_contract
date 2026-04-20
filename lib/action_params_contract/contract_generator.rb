# frozen_string_literal: true

module ActionParamsContract
  module Contracts
  end

  class ContractGenerator
    private_class_method :new

    def self.call(contract_name, &)
      new(contract_name, &).call
    end

    def call
      register_contract
    end

    private

    def initialize(contract_name, &validations)
      @contract_name = contract_name
      @validations   = validations
    end

    def register_contract
      block = @validations
      name  = @contract_name

      Contracts.const_set(name, Module.new) unless Contracts.const_defined?(name, false)

      Contracts.const_get(name, false).tap do |mod|
        mod.define_singleton_method(:schema_block) { block }

        mod.define_singleton_method(:build_contract) do
          ActionParamsContract::RequestContext.current_root = nil
          klass = Class.new(Dry::Validation::Contract)
          klass.instance_eval(&schema_block)
          klass
        end
      end
    end
  end
end
