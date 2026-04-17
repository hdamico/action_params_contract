# frozen_string_literal: true

module ActionParamsContract
  class DuplicateRegistrationError < StandardError
    def initialize(controller_class)
      super(
        "ActionParamsContract schema already registered on #{controller_class.name}. " \
        "Pick one: `validate` (soft) or `validate!` (strict), they cannot be combined."
      )
    end
  end
end
