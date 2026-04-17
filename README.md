# ActionParamsContract

Declarative Rails controller parameter validation using [dry-validation](https://dry-rb.org/gems/dry-validation/).

## Installation

Add to your Gemfile:

```ruby
gem "action_params_contract", path: "gems/action_params_contract"
```

## Usage

Define a validation schema in your controller with `ActionParamsContract.validate!` — an `around_action` is installed automatically. On failure, `ActionParamsContract::InvalidParamsError` is raised before the action runs; on success, `params` is replaced with the typed/coerced hash:

```ruby
class ArticlesController < ApplicationController
  ActionParamsContract.validate! do
    params do
      required(:title).filled(:string)
      optional(:page).filled(:integer).default(1)

      on_create { required(:author_id).filled(:integer) }
      on_update { required(:id).filled(:integer) }
    end
  end
end
```

**Pick one or the other:** a controller may register either `validate` or `validate!`, but not both — calling either method twice on the same controller (or mixing them) raises `ActionParamsContract::DuplicateRegistrationError` at load time.

If you prefer to inspect validation errors yourself instead of raising, use the non-bang `validate` — errors are exposed via `ActionParamsContract.params_errors` (without polluting `params`) and the action runs normally. Defaults and coercion still apply:

```ruby
class ArticlesController < ApplicationController
  ActionParamsContract.validate do
    params do
      required(:title).filled(:string)
    end
  end

  def create
    if ActionParamsContract.params_errors.present?
      render json: { errors: ActionParamsContract.params_errors }, status: :unprocessable_entity
    else
      Article.create!(ActionParamsContract.filtered_params)
    end
  end
end
```

### Action-conditional params

Wrap param definitions in action blocks to apply them only for specific actions:

- `on_create { ... }` - only for the `create` action
- `on_update { ... }` - only for the `update` action
- `on_index { ... }` - only for the `index` action
- `on_destroy { ... }` - only for the `destroy` action
- `on_actions(:create, :update) { ... }` - for multiple actions

### Default values

Use the `default(value)` macro on optional params:

```ruby
optional(:per_page).filled(:integer).default(25)
```

### Rescuing the strict variant

When using `validate!`, rescue `ActionParamsContract::InvalidParamsError` in your base controller to produce a uniform error response. The exception carries the validation failures as `#errors`:

```ruby
rescue_from ActionParamsContract::InvalidParamsError do |exception|
  render json: { errors: exception.errors }, status: :bad_request
end
```

### Integrating with Sentry / error-tracking tools

`InvalidParamsError` uses a **stable message** (`"Params failed validation"`) so all occurrences group into a single Sentry issue instead of one issue per unique params combination. The per-request detail lives on `#errors`. Attach it as context in your rescue handler:

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

Equivalents for other tools:

- **Bugsnag**: `Bugsnag.notify(exception) { |report| report.add_metadata(:params_validation, exception.errors) }`
- **Honeybadger**: `Honeybadger.notify(exception, context: { errors: exception.errors })`
- **Rollbar**: `Rollbar.error(exception, errors: exception.errors)`
- **Plain Rails log**: `Rails.logger.warn("[ParamsValidation] #{controller_path}##{action_name} failed: #{exception.errors.inspect}")`

**Don't** put `exception.errors` into the message itself — doing so breaks Sentry's issue grouping and creates log noise. Keep the message stable and let the structured attribute carry the detail.

### filtered_params

Call `ActionParamsContract.filtered_params` inside a validated action to get the validated params without Rails internal keys (`format`, `controller`, `action`, `locale`):

```ruby
def create
  Article.create!(ActionParamsContract.filtered_params)
end
```

If your form nests attributes under the model name (Rails' default form-builder pattern), declare `root :key` inside the schema block. `ActionParamsContract.filtered_params` will then return the *unwrapped* sub-hash, ready to hand to a model constructor:

```ruby
class ArticlesController < ApplicationController
  ActionParamsContract.validate! do
    params do
      root :article

      required(:article).hash do
        required(:title).filled(:string)
        required(:body).filled(:string)
      end
    end
  end

  def create
    # Request body: { article: { title: "Hi", body: "..." } }
    # ActionParamsContract.filtered_params => { "title" => "Hi", "body" => "..." }
    Article.create!(ActionParamsContract.filtered_params)
  end
end
```

## Configuration

By default, the Rails-internal keys `:format`, `:controller`, `:action`, and `:locale` are preserved on the validated params hash (everything else is dropped unless declared in the schema). Override the list in an initializer:

```ruby
# config/initializers/action_params_contract.rb
ActionParamsContract.configure do |config|
  config.whitelisted_params = %i[format controller action locale tenant_id]
end
```

## License

MIT
