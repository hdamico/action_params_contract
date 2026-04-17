# frozen_string_literal: true

module ActionParamsContract
  module DryExtensions
    class SchemaDsl < Dry::Schema::DSL
      include ControllerActionDsl

      def root(key)
        controller = ActionParamsContract::RequestContext.current_controller
        return unless controller

        existing = controller.instance_variable_get(:@params_object_root)
        raise ActionParamsContract::ConflictingRootError.new(existing, key) if existing && existing != key

        controller.instance_variable_set(:@params_object_root, key)
      end
    end
  end
end
