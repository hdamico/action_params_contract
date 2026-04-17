# frozen_string_literal: true

module Api
  module V2
    class NamespacedUsersController < ApplicationController
      ActionParamsContract.validate! do
        params do
          required(:title).filled(:string)
        end
      end
    end
  end
end

module CollisionA
  class WidgetsController < ApplicationController
    ActionParamsContract.validate! do
      params { required(:from_a).filled(:string) }
    end
  end
end

class CollisionAWidgetsController < ApplicationController
  ActionParamsContract.validate! do
    params { required(:from_flat).filled(:string) }
  end
end

RSpec.describe ActionParamsContract do
  describe ".validate! on a namespaced controller" do
    it "joins :: with _ to keep namespaces distinguishable" do
      expect(ActionParamsContract::Contracts.const_defined?(:Api_V2_NamespacedUsersControllerSchema, false)).to be(true)
    end

    it "does not pollute the top-level namespace" do
      expect(Object.const_defined?(:Api_V2_NamespacedUsersControllerSchema, false)).to be(false)
    end
  end

  describe ".validate! constant naming under namespace collision" do
    it "produces distinct schema constants for nested vs flat names with the same letters", :aggregate_failures do
      expect(ActionParamsContract::Contracts.const_defined?(:CollisionA_WidgetsControllerSchema, false)).to be(true)
      expect(ActionParamsContract::Contracts.const_defined?(:CollisionAWidgetsControllerSchema, false)).to be(true)
    end

    it "keeps each controller's schema rules independent", :aggregate_failures do
      nested_errors = ActionParamsContract::Contracts::CollisionA_WidgetsControllerSchema.build_contract.new.call({}).errors.to_h
      flat_errors   = ActionParamsContract::Contracts::CollisionAWidgetsControllerSchema.build_contract.new.call({}).errors.to_h

      expect(nested_errors.keys).to contain_exactly(:from_a)
      expect(flat_errors.keys).to contain_exactly(:from_flat)
    end
  end

  describe ".validate with no block" do
    it "does not install the validation callback on the controller" do
      controller = Class.new(ApplicationController) do
        def self.name = "NoBlockValidateController"
      end

      controller.class_eval { ActionParamsContract.validate }

      expect(ActionParamsContract::ControllerInstaller.installed?(controller)).to be(false)
    end
  end

  describe ".validate! with no block" do
    it "does not install the validation callback on the controller" do
      controller = Class.new(ApplicationController) do
        def self.name = "NoBlockValidateBangController"
      end

      controller.class_eval { ActionParamsContract.validate! }

      expect(ActionParamsContract::ControllerInstaller.installed?(controller)).to be(false)
    end
  end

  describe ".validate! on an anonymous controller class" do
    it "raises a clear ArgumentError instead of a cryptic NoMethodError" do
      controller = Class.new(ApplicationController)

      expect do
        controller.class_eval do
          ActionParamsContract.validate! { params { required(:a).filled(:string) } }
        end
      end.to raise_error(ArgumentError, /named controller class/)
    end
  end

  describe ".validate! called from a non-controller receiver" do
    context "when called from a plain class body (not ActionController)" do
      it "raises ArgumentError pointing at the wrong receiver" do
        expect do
          Class.new do
            def self.name = "NotAController"

            ActionParamsContract.validate! { params { required(:a).filled(:string) } }
          end
        end.to raise_error(ArgumentError, /Rails controller class body/)
      end
    end

    context "when called from a Module body" do
      it "also raises ArgumentError" do
        expect do
          Module.new do
            ActionParamsContract.validate! { params { required(:a).filled(:string) } }
          end
        end.to raise_error(ArgumentError, /Rails controller class body/)
      end
    end
  end

  describe ".configuration" do
    it "memoizes a single Configuration instance" do
      expect(described_class.configuration).to equal(described_class.configuration)
    end
  end

  describe ".configure" do
    around do |example|
      original = described_class.configuration.whitelisted_params.dup
      example.run
      described_class.configuration.whitelisted_params = original
    end

    it "yields the memoized configuration for mutation" do
      described_class.configure { |config| config.whitelisted_params = %i[format tenant] }

      expect(described_class.configuration.whitelisted_params).to eq(%i[format tenant])
    end
  end

  describe ".filtered_params" do
    after { ActionParamsContract::RequestContext.pop }

    context "when called outside a validated controller action" do
      before { ActionParamsContract::RequestContext.pop }

      it "raises a descriptive error" do
        expect { described_class.filtered_params }.to raise_error(
          ActionParamsContract::MissingRequestContextError,
          /ActionParamsContract\.filtered_params must be called from within a validated controller action/
        )
      end
    end
  end

  describe ".params_errors" do
    after { ActionParamsContract::RequestContext.pop }

    context "when called outside a validated controller action" do
      before { ActionParamsContract::RequestContext.pop }

      it "returns an empty hash rather than raising" do
        expect(described_class.params_errors).to eq({})
      end
    end

    context "when a controller has errors recorded" do
      subject(:params_errors) { described_class.params_errors }

      let(:controller) { Object.new }

      before do
        controller.instance_variable_set(ActionParamsContract::ParamsValidator::ERRORS_IVAR, name: ["is missing"])
        ActionParamsContract::RequestContext.store[ActionParamsContract::RequestContext::CONTROLLER_KEY] = controller
      end

      it "returns the recorded errors" do
        expect(params_errors).to eq(name: ["is missing"])
      end
    end
  end
end
