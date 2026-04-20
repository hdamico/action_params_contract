# frozen_string_literal: true

module ActionParamsContract
  module Params
    class << self
      def filter(params, controller: nil, action: nil)
        controller, action = resolve_target(controller, action)
        contract_module    = Contracts.const_get(schema_name_for(controller), false)
        result, root_key   = run_contract(contract_module, params, action)

        ActionController::Parameters.new(scoped_payload(result, root_key)).permit!
      end

      private

      def resolve_target(controller, action)
        controller ||= RequestContext.current_controller&.class
        action     ||= RequestContext.current_action
        raise MissingRequestContextError if controller.nil? || action.nil?

        [controller, action]
      end

      def schema_name_for(controller_class)
        "#{controller_class.name.gsub("::", "_")}Schema"
      end

      def scoped_payload(result, root_key)
        validated = result.success? ? result.to_h : {}
        root_key ? Hash(validated[root_key]) : validated
      end

      def run_contract(contract_module, params, action)
        RequestContext.with_simulated(action) do
          DryExtensions::ValidationScope.enabled do
            result = contract_module.build_contract.new.call(coerce_input(params))
            [result, RequestContext.current_root]
          end
        end
      end

      def coerce_input(params)
        return params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
        return params.to_h        if params.respond_to?(:to_h)

        params
      end
    end
  end
end
