# frozen_string_literal: true

RSpec.describe ActionParamsContract::Params do
  after { ActionParamsContract::RequestContext.pop }

  describe ".cast" do
    context "when called with no defaults available in RequestContext" do
      before { ActionParamsContract::RequestContext.pop }

      it "raises MissingRequestContextError" do
        expect { described_class.cast({}) }.to raise_error(
          ActionParamsContract::MissingRequestContextError,
          "You must call within a validated controller action"
        )
      end
    end

    context "when called with explicit controller and action outside a request" do
      let(:controller_class) do
        Class.new(ApplicationController) do
          def self.name = "ExplicitCastParamsController"

          ActionParamsContract.validate! do
            params do
              required(:title).filled(:string)
              optional(:age).filled(:integer)
            end
          end
        end
      end

      it "validates the input and returns a permitted Parameters object", :aggregate_failures do
        controller_class

        result = described_class.cast(
          { title: "Hello", age: "30", evil: "x" },
          controller: controller_class,
          action: :create
        )

        expect(result).to be_a(ActionController::Parameters)
        expect(result.permitted?).to be(true)
        expect(result.to_h).to eq("title" => "Hello", "age" => 30)
      end

      it "returns an empty permitted Parameters when validation fails", :aggregate_failures do
        controller_class

        result = described_class.cast(
          {},
          controller: controller_class,
          action: :create
        )

        expect(result.to_h).to eq({})
        expect(result.permitted?).to be(true)
      end
    end

    context "when called with an explicit action that gates rules" do
      let(:controller_class) do
        Class.new(ApplicationController) do
          def self.name = "ActionGatedCastParamsController"

          ActionParamsContract.validate! do
            params do
              on_create { required(:title).filled(:string) }
              on_update { required(:body).filled(:string) }
            end
          end
        end
      end

      it "honors the action when running the contract", :aggregate_failures do
        controller_class

        update_result = described_class.cast(
          { body: "content" },
          controller: controller_class,
          action: :update
        )
        create_result = described_class.cast(
          { title: "title" },
          controller: controller_class,
          action: :create
        )

        expect(update_result.to_h).to eq("body" => "content")
        expect(create_result.to_h).to eq("title" => "title")
      end
    end
  end
end
