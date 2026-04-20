# frozen_string_literal: true

module ActionParamsContract
  module RequestContext
    ACTION_KEY     = :dry_params_validatable_action
    CONTROLLER_KEY = :dry_params_validatable_controller
    ROOT_KEY       = :dry_params_validatable_root
    STACK_KEY      = :dry_params_validatable_stack

    class << self
      def store = ActiveSupport::IsolatedExecutionState

      def current_action     = store[ACTION_KEY]
      def current_controller = store[CONTROLLER_KEY]
      def current_root       = store[ROOT_KEY]

      def current_root=(key)
        store[ROOT_KEY] = key
      end

      def push(controller)
        push_frame(controller.action_name.to_sym, controller)
      end

      def pop
        stack = store[STACK_KEY]
        if stack.nil? || stack.empty?
          store[ACTION_KEY]     = nil
          store[CONTROLLER_KEY] = nil
          store[ROOT_KEY]       = nil
        else
          prev_action, prev_controller, prev_root = stack.pop
          store[ACTION_KEY]     = prev_action
          store[CONTROLLER_KEY] = prev_controller
          store[ROOT_KEY]       = prev_root
        end
      end

      def around(controller)
        push(controller)
        yield
      ensure
        pop
      end

      def with_simulated(action)
        push_frame(action.to_sym, nil)
        yield
      ensure
        pop
      end

      private

      def push_frame(action, controller)
        stack = store[STACK_KEY] ||= []
        stack.push([store[ACTION_KEY], store[CONTROLLER_KEY], store[ROOT_KEY]])
        store[ACTION_KEY]     = action
        store[CONTROLLER_KEY] = controller
        store[ROOT_KEY]       = nil
      end
    end
  end
end
