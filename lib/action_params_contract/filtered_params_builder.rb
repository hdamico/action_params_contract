# frozen_string_literal: true

module ActionParamsContract
  class FilteredParamsBuilder
    private_class_method :new

    def self.call(controller) = new(controller).call

    def initialize(controller)
      @controller = controller
    end

    def call
      return {} if validation_failed?

      root = @controller.instance_variable_get(:@params_object_root)
      return filtered_root(root) if root

      @controller.params.except(*ActionParamsContract.configuration.whitelisted_params).permit!.to_h
    end

    private

    def validation_failed?
      @controller.instance_variable_get(ParamsValidator::ERRORS_IVAR).present?
    end

    def filtered_root(root)
      value = @controller.params[root]
      return {} unless value.respond_to?(:permit!)

      value.permit!.to_h
    end
  end
end
