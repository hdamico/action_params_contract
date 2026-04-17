# frozen_string_literal: true

module ActionParamsContract
  module DryExtensions
    module DefaultMacro
      def default(value)
        return super unless ValidationScope.active?

        raise ActionParamsContract::DefaultOnRequiredError, name if is_a?(Dry::Schema::Macros::Required)

        schema_dsl.before(:rule_applier) do |result|
          next if result.key?(name)

          result.update(name => DefaultMacro.materialize(value))
        end
      end

      def self.materialize(value)
        return value.call if value.is_a?(Proc)

        value.dup
      rescue TypeError
        value
      end

      def self.apply! = Dry::Schema::Macros::DSL.prepend(self)
    end
  end
end
