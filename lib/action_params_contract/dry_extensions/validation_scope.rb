# frozen_string_literal: true

module ActionParamsContract
  module DryExtensions
    module ValidationScope
      FLAG = :dry_params_validatable_active

      def self.active? = RequestContext.store[FLAG] == true

      def self.enabled
        previous = RequestContext.store[FLAG]
        RequestContext.store[FLAG] = true
        yield
      ensure
        RequestContext.store[FLAG] = previous
      end
    end
  end
end
