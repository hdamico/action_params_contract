# frozen_string_literal: true

module ActionParamsContract
  class MissingRequestContextError < RuntimeError
    def initialize
      super("You must call within a validated controller action")
    end
  end
end
