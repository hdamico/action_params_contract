# frozen_string_literal: true

module ActionParamsContract
  class InvalidReceiverError < ArgumentError
    def initialize(controller_class)
      super(
        "ActionParamsContract.validate/validate! must be called from a Rails controller class body " \
        "(got #{controller_class.inspect})"
      )
    end
  end
end
