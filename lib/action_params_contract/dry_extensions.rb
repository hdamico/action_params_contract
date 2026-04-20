# frozen_string_literal: true

require_relative "errors/default_on_required_error"
require_relative "dry_extensions/controller_action_dsl"
require_relative "dry_extensions/evaluator"
require_relative "dry_extensions/schema_dsl"
require_relative "dry_extensions/validation_scope"
require_relative "dry_extensions/rule_prepend"
require_relative "dry_extensions/schema_dsl_prepend"
require_relative "dry_extensions/default_macro"

module ActionParamsContract
  module DryExtensions
    def self.apply!
      RulePrepend.apply!
      SchemaDslPrepend.apply!
      DefaultMacro.apply!
    end
  end
end
