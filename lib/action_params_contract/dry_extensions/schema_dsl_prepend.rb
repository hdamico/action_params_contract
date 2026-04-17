# frozen_string_literal: true

module ActionParamsContract
  module DryExtensions
    module SchemaDslPrepend
      def new(...)
        return super unless ValidationScope.active?
        return super unless self == Dry::Schema::DSL

        SchemaDsl.new(...)
      end

      def self.apply! = Dry::Schema::DSL.singleton_class.prepend(self)
    end
  end
end
