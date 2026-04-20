# ActionParamsContract

Declarative Rails controller parameter validation, powered by [dry-validation](https://dry-rb.org/gems/dry-validation). You can define a schema next to your actions. The gem installs an `around_action`, changes params to the declared types, and raises a structured error or exposes the failures for you to handle.

## Requirements

Ruby ≥ 3.1, Rails ≥ 7.0.

## Installation

```ruby
gem "action_params_contract"
```

Then run `bundle install`.

## Usage

Declare the schema in the controller body. If successful, `params` is replaced with the typed or changed hash. If it fails, `ActionParamsContract::InvalidParamsError` is raised before the action runs.

```ruby
class ArticlesController < ApplicationController
  ActionParamsContract.validate! do
    params do
      root :article

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
    Article.create!(ActionParamsContract::Params.filter(params))
  end
end
```

Rescue the error in your base controller for a consistent response:

```ruby
rescue_from ActionParamsContract::InvalidParamsError do |exception|
  render json: { errors: exception.errors }, status: :bad_request
end
```

## Strict vs. Soft

- `validate!` raises `InvalidParamsError` on failure, so the action never runs.
- `validate` records errors in the controller and lets the action run. You can inspect them using `ActionParamsContract.params_errors`.

```ruby
ActionParamsContract.validate do
  params { required(:title).filled(:string) }
end

def create
  return render(json: { errors: ActionParamsContract.params_errors }, status: :unprocessable_entity) if ActionParamsContract.params_errors.present?

  Article.create!(ActionParamsContract::Params.filter(params))
end
```

A controller can register **only one**, not both. A second call or mixing `validate` and `validate!` raises `DuplicateRegistrationError` at load time.

## Action-Conditional DSL

Scope rules to specific actions:

- `on_create { ... }`, `on_update { ... }`, `on_index { ... }`, `on_destroy { ... }`
- `on_actions(:create, :update) { ... }` for multiple actions
- `current_action?(:create)` as a predicate form

These also work inside `rule` blocks, allowing cross-field rules to branch per action.

## `Params.filter` and `root`

`ActionParamsContract::Params.filter(params)` runs the registered contract against the supplied hash and returns an `ActionController::Parameters` object whose contents are exactly the contract-validated keys, already permitted. `User.update(ActionParamsContract::Params.filter(params))` works without any additional `permit` call. If your schema declares `root :key`, the sub-hash under that key is returned unwrapped:

```ruby
# Request body: { article: { title: "Hi", body: "..." } }
ActionParamsContract::Params.filter(params)
# => #<ActionController::Parameters {"title"=>"Hi", "body"=>"..."} permitted: true>
```

Inside a controller action both the controller class and the action name are pulled from the request context, so the implicit form above is enough. From a plain Ruby object (service, job, rake task) pass them explicitly:

```ruby
ActionParamsContract::Params.filter(params, controller: ArticlesController, action: :create)
```

If validation fails, `Params.filter` returns an empty permitted `Parameters` object, so downstream `Model.update(...)` calls become a safe no-op. The raise-vs-no-raise behavior is decided at install time via `validate!` vs `validate`; `Params.filter` just returns the validated view.

## Configuration

Override the list of Rails-internal keys you want to keep:

```ruby
# config/initializers/action_params_contract.rb
ActionParamsContract.configure do |config|
  config.whitelisted_params = %i[format controller action locale tenant_id]
end
```

## Error Tracking

`InvalidParamsError` uses a stable message (`"Params failed validation"`), grouping occurrences into a single issue in tools like Sentry instead of breaking them down per input. Attach `#errors` as structured context in your rescue handler:

```ruby
rescue_from ActionParamsContract::InvalidParamsError do |exception|
  Sentry.with_scope do |scope|
    scope.set_context("params_validation", { errors: exception.errors })
    scope.set_tags(controller: controller_path, action: action_name)
    Sentry.capture_exception(exception)
  end

  render json: { errors: exception.errors }, status: :bad_request
end
```

Equivalents include: `Bugsnag.notify(exception) { |r| r.add_metadata(:params_validation, exception.errors) }`, `Honeybadger.notify(exception, context: { errors: exception.errors })`, and `Rollbar.error(exception, errors: exception.errors)`. Keep `exception.errors` out of the message itself, as it can disrupt grouping.

## What This Gem Is Not

Validation semantics, types, predicates, `rule` blocks, and error formatting are all part of dry-validation. Refer to its [documentation](https://dry-rb.org/gems/dry-validation/) for the complete reference. This gem provides Rails integration, action conditionals, `root` unwrapping, and the `default` macro on top.

## License

MIT.
