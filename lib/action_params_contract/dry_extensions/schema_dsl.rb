# frozen_string_literal: true

module ActionParamsContract
  module DryExtensions
    class SchemaDsl < Dry::Schema::DSL
      include ControllerActionDsl

      def root(key)
        existing = ActionParamsContract::RequestContext.current_root
        raise ActionParamsContract::ConflictingRootError.new(existing, key) if existing && existing != key

        ActionParamsContract::RequestContext.current_root = key
      end
    end
  end
end
