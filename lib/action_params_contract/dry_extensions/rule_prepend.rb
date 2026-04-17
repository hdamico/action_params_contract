# frozen_string_literal: true

module ActionParamsContract
  module DryExtensions
    module RulePrepend
      def call(contract, result)
        return super unless ValidationScope.active?

        Evaluator.new(
          contract,
          keys:,
          macros:,
          block_options:,
          result:,
          values: result.values,
          _context: result.context,
          &block
        )
      end

      def self.apply! = Dry::Validation::Rule.prepend(self)
    end
  end
end
