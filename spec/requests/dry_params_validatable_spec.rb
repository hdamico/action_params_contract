# frozen_string_literal: true

class BasicValidationController < ApplicationController
  ActionParamsContract.validate! do
    params do
      required(:name).filled(:string)
      optional(:age).filled(:integer)
    end
  end

  def create
    render json: { name: params[:name], age: params[:age] }
  end

  def index
    render json: { status: "ok" }
  end
end

class ActionConditionalController < ApplicationController
  ActionParamsContract.validate! do
    params do
      on_create { required(:title).filled(:string) }
      on_update { required(:body).filled(:string) }
      on_index  { optional(:page).filled(:integer) }
    end
  end

  def create
    render json: { title: params[:title] }
  end

  def update
    render json: { body: params[:body] }
  end

  def index
    render json: { page: params[:page] }
  end
end

class DefaultValueController < ApplicationController
  ActionParamsContract.validate! do
    params do
      optional(:page).filled(:integer).default(1)
      optional(:per_page).filled(:integer).default(25)
      required(:query).filled(:string)
    end
  end

  def index
    render json: { page: params[:page], per_page: params[:per_page], query: params[:query] }
  end
end

class MultiActionController < ApplicationController
  ActionParamsContract.validate! do
    params do
      on_actions(:create, :update) { required(:name).filled(:string) }
      on_destroy { optional(:reason).filled(:string) }
    end
  end

  def create
    render json: { name: params[:name] }
  end

  def update
    render json: { name: params[:name] }
  end

  def destroy
    render json: { status: "deleted" }
  end

  def index
    render json: { status: "ok" }
  end
end

class SoftValidationController < ApplicationController
  ActionParamsContract.validate do
    params do
      required(:name).filled(:string)
    end
  end

  def create
    render json: { name: params[:name], errors: ActionParamsContract.params_errors }
  end
end

class RootObjectController < ApplicationController
  ActionParamsContract.validate! do
    params do
      root :article

      required(:article).hash do
        required(:title).filled(:string)
      end
    end
  end

  def create
    filtered = ActionParamsContract::Params.filter(params)
    render json: { filtered_params: filtered.to_h, permitted: filtered.permitted? }
  end
end

class StripNonSchemaController < ApplicationController
  ActionParamsContract.validate! do
    params do
      required(:name).filled(:string)
    end
  end

  def create
    render json: { name: params[:name], evil: params[:evil] }
  end
end

class DestroyRequiredController < ApplicationController
  ActionParamsContract.validate! do
    params do
      on_destroy { required(:confirmation).filled(:string) }
    end
  end

  def destroy
    render json: { status: "deleted" }
  end
end

class SoftDefaultsController < ApplicationController
  ActionParamsContract.validate do
    params do
      optional(:page).filled(:integer).default(1)
    end
  end

  def index
    render json: { page: params[:page] }
  end
end

class NoRootObjectController < ApplicationController
  ActionParamsContract.validate! do
    params do
      required(:name).filled(:string)
    end
  end

  def create
    filtered = ActionParamsContract::Params.filter(params)
    render json: { filtered_params: filtered.to_h, permitted: filtered.permitted? }
  end
end

class SoftRootObjectController < ApplicationController
  ActionParamsContract.validate do
    params do
      root :article

      required(:article).hash do
        required(:title).filled(:string)
      end
    end
  end

  def create
    render json: {
      filtered_params: ActionParamsContract::Params.filter(params).to_h,
      errors: ActionParamsContract.params_errors,
    }
  end
end

class SoftFilteredParamsController < ApplicationController
  ActionParamsContract.validate do
    params do
      required(:name).filled(:string)
    end
  end

  def create
    render json: {
      filtered_params: ActionParamsContract::Params.filter(params).to_h,
      errors: ActionParamsContract.params_errors,
    }
  end
end

class InheritedQuietController < BasicValidationController
  def create
    render json: { name: params[:name], inherited: true }
  end
end

class CustomWhitelistController < ApplicationController
  ActionParamsContract.validate! do
    params do
      required(:name).filled(:string)
    end
  end

  def create
    render json: { name: params[:name], tenant: params[:tenant], evil: params[:evil] }
  end
end

class CrossFieldRuleController < ApplicationController
  ActionParamsContract.validate! do
    params do
      required(:start_date).filled(:date)
      required(:end_date).filled(:date)
    end

    rule(:start_date, :end_date) do
      key(:end_date).failure("must be after start_date") if values[:end_date] < values[:start_date]
    end
  end

  def create
    render json: { start_date: params[:start_date].to_s, end_date: params[:end_date].to_s }
  end
end

RSpec.describe ActionParamsContract do
  let(:body) { JSON.parse(response.body) }

  before do
    Rails.application.routes.draw do
      resources :basic_validation, only: %i[index create], controller: "basic_validation"
      resources :action_conditional, only: %i[index create update], controller: "action_conditional"
      resources :default_value, only: [:index], controller: "default_value"
      resources :multi_action, only: %i[index create update destroy], controller: "multi_action"
      resources :soft_validation, only: %i[create], controller: "soft_validation"
      resources :root_object, only: %i[create], controller: "root_object"
      resources :strip_non_schema, only: %i[create], controller: "strip_non_schema"
      resources :destroy_required, only: %i[destroy], controller: "destroy_required"
      resources :soft_defaults, only: %i[index], controller: "soft_defaults"
      resources :no_root_object, only: %i[create], controller: "no_root_object"
      resources :custom_whitelist, only: %i[create], controller: "custom_whitelist"
      resources :soft_root_object, only: %i[create], controller: "soft_root_object"
      resources :soft_filtered_params, only: %i[create], controller: "soft_filtered_params"
      resources :inherited_quiet, only: %i[create], controller: "inherited_quiet"
      resources :cross_field_rule, only: %i[create], controller: "cross_field_rule"
    end
  end

  after do
    Rails.application.routes_reloader.reload!
  end

  describe "POST create with required param validation" do
    context "when the required param is present" do
      before { post "/basic_validation", params: { name: "Alice" } }

      it "responds 200 and echoes the param", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body).to include("name" => "Alice")
      end
    end

    context "when the required param is missing" do
      before { post "/basic_validation", params: {} }

      it "responds bad_request" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the required param is empty" do
      before { post "/basic_validation", params: { name: "" } }

      it "responds bad_request" do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "POST create with optional param validation" do
    context "when the optional param is present and valid" do
      before { post "/basic_validation", params: { name: "Alice", age: 30 } }

      it "echoes both params", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body).to include("name" => "Alice", "age" => 30)
      end
    end

    context "when the optional param is omitted" do
      before { post "/basic_validation", params: { name: "Alice" } }

      it "still responds 200" do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "action-conditional validation" do
    describe "POST create gated by on_create" do
      context "when create params are valid" do
        before { post "/action_conditional", params: { title: "My Post" } }

        it "responds 200 and echoes the title", :aggregate_failures do
          expect(response).to have_http_status(:ok)
          expect(body).to include("title" => "My Post")
        end
      end

      context "when create params are missing" do
        before { post "/action_conditional", params: {} }

        it "responds bad_request" do
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    describe "PUT update gated by on_update" do
      context "when update params are valid" do
        before { put "/action_conditional/1", params: { body: "Updated content" } }

        it "responds 200" do
          expect(response).to have_http_status(:ok)
        end
      end

      context "when update params are missing" do
        before { put "/action_conditional/1", params: {} }

        it "responds bad_request" do
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    describe "GET index gated by on_index" do
      context "when index params are valid" do
        before { get "/action_conditional", params: { page: 1 } }

        it "responds 200" do
          expect(response).to have_http_status(:ok)
        end
      end

      context "when index params are omitted" do
        before { get "/action_conditional" }

        it "responds 200 because page is optional" do
          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe "cross-action isolation" do
      context "when issuing PUT update with only update params" do
        before { put "/action_conditional/1", params: { body: "Content" } }

        it "does not require create params" do
          expect(response).to have_http_status(:ok)
        end
      end

      context "when issuing POST create with only create params" do
        before { post "/action_conditional", params: { title: "Post" } }

        it "does not require update params" do
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe "default value macro" do
    context "when an optional param is omitted" do
      before { get "/default_value", params: { query: "test" } }

      it "fills in the schema-declared default", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body).to include("page" => 1, "per_page" => 25)
      end
    end

    context "when an optional param is explicitly provided" do
      before { get "/default_value", params: { query: "test", page: 3, per_page: 50 } }

      it "uses the provided value", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body).to include("page" => 3, "per_page" => 50)
      end
    end
  end

  describe "on_actions multi-action conditional" do
    context "when issuing POST create without name" do
      before { post "/multi_action", params: {} }

      it "responds bad_request" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when issuing PUT update without name" do
      before { put "/multi_action/1", params: {} }

      it "responds bad_request" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when issuing GET index without name" do
      before { get "/multi_action" }

      it "responds 200" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "when issuing DELETE destroy without name" do
      before { delete "/multi_action/1" }

      it "responds 200" do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "soft validation via ActionParamsContract.validate" do
    context "when params are valid" do
      before { post "/soft_validation", params: { name: "Alice" } }

      it "processes the request without surfacing errors", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body).to include("name" => "Alice")
        expect(body["errors"]).to be_blank
      end
    end

    context "when params are invalid" do
      before { post "/soft_validation", params: {} }

      it "exposes errors on params without raising", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body["errors"]).to include("name")
      end
    end
  end

  describe "root :key DSL for filter_params" do
    context "when the schema declares root :article and params are valid" do
      before { post "/root_object", params: { article: { title: "Hello" } } }

      it "filter_params returns a permitted Parameters object scoped to the root", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body["filtered_params"]).to eq({ "title" => "Hello" })
        expect(body["permitted"]).to be(true)
      end
    end

    context "when nested required param is missing" do
      before { post "/root_object", params: { article: {} } }

      it "responds bad_request via InvalidParamsError" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the entire root param is missing" do
      before { post "/root_object", params: {} }

      it "responds bad_request via InvalidParamsError" do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "duplicate schema registration" do
    context "when validate is called twice on the same controller" do
      let(:controller) do
        Class.new(ApplicationController) do
          def self.name = "DuplicateValidateController"
        end
      end

      before do
        controller.class_eval do
          ActionParamsContract.validate { params { required(:a).filled(:string) } }
        end
      end

      it "raises DuplicateRegistrationError" do
        expect do
          controller.class_eval do
            ActionParamsContract.validate { params { required(:b).filled(:string) } }
          end
        end.to raise_error(
          ActionParamsContract::DuplicateRegistrationError,
          /already registered on DuplicateValidateController/
        )
      end
    end

    context "when validate and validate! are mixed on the same controller" do
      let(:controller) do
        Class.new(ApplicationController) do
          def self.name = "MixedValidationController"
        end
      end

      before do
        controller.class_eval do
          ActionParamsContract.validate { params { required(:a).filled(:string) } }
        end
      end

      it "raises DuplicateRegistrationError" do
        expect do
          controller.class_eval do
            ActionParamsContract.validate! { params { required(:b).filled(:string) } }
          end
        end.to raise_error(ActionParamsContract::DuplicateRegistrationError)
      end
    end
  end

  describe "typed_params stripping in strict mode" do
    context "when params contain keys outside the schema and the whitelist" do
      before { post "/strip_non_schema", params: { name: "Alice", evil: "injected" } }

      it "removes them so the action never sees unpermitted input", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body).to include("name" => "Alice", "evil" => nil)
      end
    end
  end

  describe "DELETE destroy gated by on_destroy with a required param" do
    context "when the destroy param is missing" do
      before { delete "/destroy_required/1" }

      it "responds bad_request" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the destroy param is present" do
      before { delete "/destroy_required/1", params: { confirmation: "yes" } }

      it "responds 200" do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "soft validation and defaults" do
    context "when a default-annotated param is omitted under soft mode" do
      before { get "/soft_defaults" }

      it "still applies the default because typed_params runs on success" do
        expect(body["page"]).to eq(1)
      end
    end
  end

  describe "filter_params without the root DSL" do
    context "when no root is declared on the schema" do
      before { post "/no_root_object", params: { name: "Alice" } }

      it "returns the validated hash as a permitted Parameters object", :aggregate_failures do
        expect(body["filtered_params"]).to eq("name" => "Alice")
        expect(body["permitted"]).to be(true)
      end
    end
  end

  describe "soft-mode filter_params with non-hash root input" do
    context "when the client sends the root key as a scalar" do
      before { post "/soft_root_object", params: { article: "hello" } }

      it "returns {} from filter_params instead of raising", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body["filtered_params"]).to eq({})
        expect(body["errors"]).to include("article")
      end
    end

    context "when the root key is omitted entirely" do
      before { post "/soft_root_object", params: {} }

      it "returns {} from filter_params" do
        expect(response).to have_http_status(:ok)
        expect(body["filtered_params"]).to eq({})
      end
    end

    context "when the root key is a valid hash" do
      before { post "/soft_root_object", params: { article: { title: "Hello" } } }

      it "returns the unwrapped sub-hash with no errors", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body["filtered_params"]).to eq("title" => "Hello")
        expect(body["errors"]).to be_blank
      end
    end
  end

  describe "soft-mode filter_params when validation failed" do
    context "when the schema rejects the input" do
      before { post "/soft_filtered_params", params: { evil: "payload" } }

      it "returns {} so attacker-controlled keys are not surfaced as 'filtered'", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body["filtered_params"]).to eq({})
        expect(body["errors"]).to include("name")
      end
    end

    context "when the schema accepts the input" do
      before { post "/soft_filtered_params", params: { name: "Alice" } }

      it "returns the validated, filtered view" do
        expect(response).to have_http_status(:ok)
        expect(body["filtered_params"]).to eq("name" => "Alice")
      end
    end
  end

  describe "validation inheritance" do
    context "when a child only inherits the parent's around_action" do
      before { post "/inherited_quiet", params: { name: "Alice" } }

      it "validates against the parent schema and runs the action once", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body).to include("name" => "Alice", "inherited" => true)
      end
    end

    context "when a child re-declares validate! after inheriting" do
      it "raises DuplicateRegistrationError instead of double-registering" do
        expect do
          Class.new(BasicValidationController) do
            def self.name = "InheritedRedeclareController"

            ActionParamsContract.validate! do
              params { required(:something).filled(:string) }
            end
          end
        end.to raise_error(ActionParamsContract::DuplicateRegistrationError)
      end
    end
  end

  describe "custom whitelisted_params configuration" do
    around do |example|
      original = described_class.configuration.whitelisted_params.dup
      described_class.configuration.whitelisted_params = original + %i[tenant]
      example.run
      described_class.configuration.whitelisted_params = original
    end

    context "when a custom key is whitelisted and others are not" do
      before { post "/custom_whitelist", params: { name: "Alice", tenant: "acme", evil: "x" } }

      it "preserves the whitelisted key and strips the rest", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body).to include("name" => "Alice", "tenant" => "acme", "evil" => nil)
      end
    end
  end

  describe "cross-field rule validation" do
    context "when the rule passes" do
      before { post "/cross_field_rule", params: { start_date: "2026-01-01", end_date: "2026-02-01" } }

      it "responds 200 and echoes the params", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body).to include("start_date" => "2026-01-01", "end_date" => "2026-02-01")
      end
    end

    context "when the rule fails" do
      before { post "/cross_field_rule", params: { start_date: "2026-02-01", end_date: "2026-01-01" } }

      it "responds bad_request" do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
