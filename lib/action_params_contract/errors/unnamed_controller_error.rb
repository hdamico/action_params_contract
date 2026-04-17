# frozen_string_literal: true

module ActionParamsContract
  class UnnamedControllerError < ArgumentError
    def initialize
      super("ActionParamsContract requires a named controller class")
    end
  end
end
