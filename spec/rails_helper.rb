# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "action_params_contract"
require_relative "dummy/config/environment"
require "rspec/rails"

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.use_transactional_fixtures = false
end
