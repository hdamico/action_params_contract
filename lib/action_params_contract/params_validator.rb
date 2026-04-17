# frozen_string_literal: true

require_relative "errors/invalid_params_error"

module ActionParamsContract
  class ParamsValidator
    ERRORS_IVAR = :@__dry_params_validatable_errors

    private_class_method :new

    def self.call(...)
      new(...).call
    end

    def initialize(controller, schema_name, raise_on_failure:)
      @controller       = controller
      @schema_name      = schema_name
      @raise_on_failure = raise_on_failure
    end

    def call
      errors = validation_errors
      @controller.instance_variable_set(ERRORS_IVAR, errors)

      if errors.blank?
        @controller.params = typed_params
      elsif @raise_on_failure
        raise InvalidParamsError, errors
      end
    end

    private

    def typed_params
      whitelisted = @controller.params.slice(*ActionParamsContract.configuration.whitelisted_params)
      whitelisted.merge(validation_result.to_h)
    end

    def validation_result
      @validation_result ||= DryExtensions::ValidationScope.enabled do
        schema = Contracts.const_get(@schema_name, false)
        schema.build_contract.new.call(@controller.params.as_json)
      end
    end

    def validation_errors = validation_result.errors.to_h
  end
end
