# frozen_string_literal: true

module ActionParamsContract
  module DryExtensions
    class Evaluator < Dry::Validation::Evaluator
      include ControllerActionDsl
    end
  end
end
