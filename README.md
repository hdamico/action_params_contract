# ActionParamsContract

Declarative parameter validation for Rails controllers, built on [dry-validation](https://dry-rb.org/gems/dry-validation). You declare a schema next to your actions and the gem installs an `around_action` that coerces params to the declared types. If validation fails you can either raise or collect the errors and handle them yourself.

## Requirements

- Ruby 3.1+
- Rails 7.0+

## Installation

Add this to your Gemfile:

```ruby
gem "action_params_contract"
```

Then run `bundle install`.

## Usage

Declare the schema in the controller body. If validation passes, `params` is replaced with the coerced hash. If it fails, `ActionParamsContract::InvalidParamsError` is raised before the action runs.

```ruby
class ArticlesController < ApplicationController
  ActionParamsContract.validate! do
    params do
      optional(:page).filled(:integer).default(1)

      on_create do
        required(:article).hash do
          required(:title).filled(:string)
          required(:body).filled(:string)
        end
      end

      on_update { required(:id).filled(:integer) }
    end
  end

  def create
    Article.create!(ActionParamsContract::Params.cast(params)[:article])
  end
end
```

Rescue the error in your base controller for a consistent response:

```ruby
rescue_from ActionParamsContract::InvalidParamsError do |exception|
  render json: { errors: exception.errors }, status: :bad_request
end
```

## Strict vs. soft

Two modes, pick one per controller:

- `validate!` raises `InvalidParamsError` on failure, so the action never runs.
- `validate` records errors and lets the action run. Read them via `ActionParamsContract.params_errors`.

```ruby
ActionParamsContract.validate do
  params { required(:title).filled(:string) }
end

def create
  if ActionParamsContract.params_errors.present?
    return render(json: { errors: ActionParamsContract.params_errors }, status: :unprocessable_entity)
  end

  Article.create!(ActionParamsContract::Params.cast(params))
end
```

Mixing the two, or calling either twice in the same controller, raises `DuplicateRegistrationError` at load time.

## Action-conditional DSL

Scope rules to specific actions:

- `on_create { ... }`, `on_update { ... }`, `on_index { ... }`, `on_destroy { ... }`
- `on_actions(:create, :update) { ... }` for multiple actions
- `current_action?(:create)` as a predicate

These also work inside `rule` blocks, so cross-field rules can branch per action.

## `Params.cast`

`ActionParamsContract::Params.cast(params)` runs the registered contract against the given hash and returns an `ActionController::Parameters` object containing only the validated keys, already permitted. That means `Model.update(ActionParamsContract::Params.cast(params))` works without a separate `permit` call.

```ruby
# Request body: { article: { title: "Hi", body: "..." }, page: "2" }
ActionParamsContract::Params.cast(params)
# => #<ActionController::Parameters {"article"=>{"title"=>"Hi", "body"=>"..."}, "page"=>2} permitted: true>
```

Inside a controller action the controller class and action name are read from the request context, so you don't need to pass them. From a service, job, or rake task, pass them explicitly:

```ruby
ActionParamsContract::Params.cast(params, controller: ArticlesController, action: :create)
```

When validation fails, `cast` returns an empty permitted `Parameters` object. Whether a failure raises is decided at install time by `validate!` vs `validate`; `cast` itself just returns the validated view.

## Configuration

Override the list of Rails-internal keys you want to keep:

```ruby
# config/initializers/action_params_contract.rb
ActionParamsContract.configure do |config|
  config.whitelisted_params = %i[format controller action locale tenant_id]
end
```

## Error tracking

`InvalidParamsError` carries the failures on `#errors`. You can attach them as context in your rescue handler:

```ruby
rescue_from ActionParamsContract::InvalidParamsError do |exception|
  Sentry.with_scope do |scope|
    scope.set_context("params_validation", errors: exception.errors)
    scope.set_tags(controller: controller_path, action: action_name)
    Sentry.capture_exception(exception)
  end

  render json: { errors: exception.errors }, status: :bad_request
end
```

## License

MIT.
