# frozen_string_literal: true

require "rails"
require "action_controller/railtie"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("../..", __FILE__)
    config.load_defaults 7.0
    config.eager_load = false
    config.secret_key_base = "test-secret-key-base-for-dry-params-validatable"
    config.hosts.clear
  end
end
