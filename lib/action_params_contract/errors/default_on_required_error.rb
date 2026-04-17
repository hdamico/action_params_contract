# frozen_string_literal: true

module ActionParamsContract
  class DefaultOnRequiredError < ArgumentError
    def initialize(name)
      super(
        "default(...) on required(:#{name}) makes the key always present, " \
        "neutralising required. Use optional(:#{name}).default(...) instead."
      )
    end
  end
end
