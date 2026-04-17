# frozen_string_literal: true

require "dry-validation"
require "active_support"

require_relative "action_params_contract/version"
require_relative "action_params_contract/configuration"
require_relative "action_params_contract/request_context"
require_relative "action_params_contract/params_validator"
require_relative "action_params_contract/controller_installer"
require_relative "action_params_contract/filtered_params_builder"
require_relative "action_params_contract/schema_installer"
require_relative "action_params_contract/dry_extensions"
require_relative "action_params_contract/contract_generator"
require_relative "action_params_contract/errors/missing_request_context_error"

ActionParamsContract::DryExtensions.apply!

module ActionParamsContract
  FILTERED_IVAR = :@__dry_params_validatable_filtered

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def validate(&block)  = SchemaInstaller.call(block, raise_on_failure: false)
    def validate!(&block) = SchemaInstaller.call(block, raise_on_failure: true)

    def filtered_params
      controller = RequestContext.current_controller || raise(MissingRequestContextError, :filtered_params)

      return controller.instance_variable_get(FILTERED_IVAR) if controller.instance_variable_defined?(FILTERED_IVAR)

      controller.instance_variable_set(FILTERED_IVAR, FilteredParamsBuilder.call(controller))
    end

    def params_errors
      Hash(RequestContext.current_controller&.instance_variable_get(ParamsValidator::ERRORS_IVAR))
    end
  end
end
