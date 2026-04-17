# frozen_string_literal: true

module ActionParamsContract
  module DryExtensions
    module ControllerActionDsl
      def current_action?(action)
        current = ActionParamsContract::RequestContext.current_action
        return false if current.nil?

        current == action.to_sym
      end

      def on_actions(*names)
        names.each do |name|
          yield if block_given? && current_action?(name)
        end
      end

      def on_action(name)
        yield if block_given? && current_action?(name)
      end

      def on_index   = on_action(:index)   { yield if block_given? }
      def on_update  = on_action(:update)  { yield if block_given? }
      def on_create  = on_action(:create)  { yield if block_given? }
      def on_destroy = on_action(:destroy) { yield if block_given? }
    end
  end
end
