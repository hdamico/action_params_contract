# frozen_string_literal: true

module ActionParamsContract
  module ControllerInstaller
    INSTALLED_FLAG = :@__dry_params_validatable_installed

    class << self
      def install(controller_class, schema_name, raise_on_failure:)
        controller_class.define_method(:_dry_params_validatable_around) do |&action|
          RequestContext.around(self) do
            ParamsValidator.call(self, schema_name, raise_on_failure:)
            action.call
          end
        end
        controller_class.around_action :_dry_params_validatable_around
        controller_class.instance_variable_set(INSTALLED_FLAG, true)
      end

      def installed?(controller_class)
        controller_class.ancestors.any? do |ancestor|
          ancestor.is_a?(Class) && ancestor.instance_variable_defined?(INSTALLED_FLAG)
        end
      end
    end
  end
end
