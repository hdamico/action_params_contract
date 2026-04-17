# frozen_string_literal: true

require_relative "errors/duplicate_registration_error"
require_relative "errors/invalid_receiver_error"
require_relative "errors/unnamed_controller_error"

module ActionParamsContract
  class SchemaInstaller
    private_class_method :new

    def self.call(...)
      new(...).call
    end

    def initialize(block, raise_on_failure:)
      @block            = block
      @raise_on_failure = raise_on_failure
    end

    def call
      return unless @block

      validate_receiver!
      raise DuplicateRegistrationError, controller_class if ControllerInstaller.installed?(controller_class)

      ControllerInstaller.install(controller_class, schema_name, raise_on_failure: @raise_on_failure)
      ContractGenerator.call(schema_name, &@block)
    end

    private

    def controller_class = @controller_class ||= @block.binding.receiver

    def validate_receiver!
      return if controller_class.is_a?(Class) && controller_class < ActionController::Metal

      raise InvalidReceiverError, controller_class
    end

    def schema_name
      raise UnnamedControllerError unless controller_class.name

      "#{controller_class.name.gsub("::", "_")}Schema"
    end
  end
end
