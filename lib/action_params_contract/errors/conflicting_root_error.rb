# frozen_string_literal: true

module ActionParamsContract
  class ConflictingRootError < ArgumentError
    def initialize(existing, key)
      super("root :#{existing} already declared on this schema; cannot also declare root :#{key}")
    end
  end
end
