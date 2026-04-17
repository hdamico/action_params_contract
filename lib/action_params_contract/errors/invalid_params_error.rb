# frozen_string_literal: true

module ActionParamsContract
  class InvalidParamsError < StandardError
    attr_reader :errors

    def initialize(errors = {})
      @errors = errors
      super("Params failed validation")
    end
  end
end
