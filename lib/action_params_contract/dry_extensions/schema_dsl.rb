# frozen_string_literal: true

module ActionParamsContract
  module DryExtensions
    class SchemaDsl < Dry::Schema::DSL
      include ControllerActionDsl
    end
  end
end
