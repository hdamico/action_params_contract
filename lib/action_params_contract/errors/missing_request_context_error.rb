# frozen_string_literal: true

module ActionParamsContract
  class MissingRequestContextError < RuntimeError
    def initialize(method_name)
      super(
        "ActionParamsContract.#{method_name} must be called from within a validated controller action"
      )
    end
  end
end
