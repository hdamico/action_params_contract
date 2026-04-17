# frozen_string_literal: true

module ActionParamsContract
  module RequestContext
    ACTION_KEY     = :dry_params_validatable_action
    CONTROLLER_KEY = :dry_params_validatable_controller
    STACK_KEY      = :dry_params_validatable_stack

    class << self
      def store = ActiveSupport::IsolatedExecutionState

      def current_action     = store[ACTION_KEY]
      def current_controller = store[CONTROLLER_KEY]

      def push(controller)
        stack = store[STACK_KEY] ||= []
        stack.push([store[ACTION_KEY], store[CONTROLLER_KEY]])
        store[ACTION_KEY]     = controller.action_name.to_sym
        store[CONTROLLER_KEY] = controller
      end

      def pop
        stack = store[STACK_KEY]
        if stack.nil? || stack.empty?
          store[ACTION_KEY]     = nil
          store[CONTROLLER_KEY] = nil
        else
          prev_action, prev_controller = stack.pop
          store[ACTION_KEY]     = prev_action
          store[CONTROLLER_KEY] = prev_controller
        end
      end

      def around(controller)
        push(controller)
        yield
      ensure
        pop
      end
    end
  end
end
