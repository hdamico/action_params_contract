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
    Article.create!(ActionParamsContract.filtered_params)
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

  Article.create!(ActionParamsContract.filtered_params)
end
```

A controller can register **only one**, not both. A second call or mixing `validate` and `validate!` raises `DuplicateRegistrationError` at load time.

## Action-Conditional DSL

Scope rules to specific actions:

- `on_create { ... }`, `on_update { ... }`, `on_index { ... }`, `on_destroy { ... }`
- `on_actions(:create, :update) { ... }` for multiple actions
- `current_action?(:create)` as a predicate form

These also work inside `rule` blocks, allowing cross-field rules to branch per action.

## `filtered_params` and `root`

`ActionParamsContract.filtered_params` returns the validated params with Rails internals (such as `format`, `controller`, `action`, and `locale`) removed. If your schema declares `root :key`, the sub-hash under that key is returned unwrapped, ready to use for a model:

```ruby
# Request body: { article: { title: "Hi", body: "..." } }
ActionParamsContract.filtered_params # => { "title" => "Hi", "body" => "..." }
```

The plain `params` also works inside the action, holding the same typed or changed hash on success.

It does not negate or override the strong parameters; it can live alongside them. `params` is still a `ActionController::Parameters` instance, meaning you can call `params.require(:article).permit(:title, :body)` as usual if you choose. However, the difference now is that with your schema defined, you do not typically need this. Your values will be returned in a regular Hash by way of `filtered_params`, having been type-checked and type-coerced according to the defined schema, with any undeclared keys removed automatically.

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
