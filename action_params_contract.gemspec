# frozen_string_literal: true

require_relative "lib/action_params_contract/version"

Gem::Specification.new do |spec|
  spec.name          = "action_params_contract"
  spec.email         = ["hernan.damico67@gmail.com"]
  spec.version       = ActionParamsContract::VERSION
  spec.authors       = ["hdamico"]
  spec.homepage      = "https://github.com/hdamico/action_params_contract"
  spec.summary       = "Declarative Rails controller parameter validation using dry-validation"
  spec.description   = "A Rails concern that provides action-conditional parameter validation schemas " \
                       "powered by dry-validation, with thread-safe per-request contract building."
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "actionpack",    ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "dry-schema", "~> 1.13"
  spec.add_dependency "dry-validation", "~> 1.10"

  spec.metadata["rubygems_mfa_required"] = "true"
end
