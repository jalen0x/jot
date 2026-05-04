---
paths:
  - "app/controllers/api/**/*.rb"
  - "app/controllers/api_controller.rb"
  - "test/integration/api/**/*.rb"
  - "config/routes.rb"
---

# API Endpoint Standards

## First Clarify the Use Case

Before adding an API, write down who uses it and why: internal Ajax, internal service integration, partner integration, or public product API. Do not build public-API complexity for a private JSON endpoint.

## Architecture

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :widgets, only: [:index, :show, :create]
  end
end
```

```ruby
# app/controllers/api_controller.rb — base class for all API controllers
class ApiController < ApplicationController
  before_action :authenticate
  before_action :require_json

  private

  def authenticate
    authenticate_or_request_with_http_token do |token, _options|
      ApiKey.find_by(key: token, deactivated_at: nil).present?
    end
  end

  def require_json
    head :not_acceptable unless request.format.json?
  end
end
```

```ruby
# app/controllers/api/v1/widgets_controller.rb
class Api::V1::WidgetsController < ApiController
  def show
    widget = Widget.find(params[:id])
    render json: { widget: widget }
  end
end
```

## Authentication Strategy (Simplest Sufficient)

| Scenario | Approach |
|---|---|
| Frontend Ajax | Reuse existing Cookie authentication (Devise session) |
| Internal service-to-service | HTTP Token Auth — one key per client |
| Public API | JWT / OAuth (introduce only when needed, not prematurely) |

API Key table should have a conditional unique index: `add_index :api_keys, :client_name, unique: true, where: "deactivated_at IS NULL"`.

## JSON Responses

Render JSON with Rails' native `to_json` / `as_json` path unless there is a concrete reason not to. If you find yourself building a large custom hash in the controller or creating a class only to serialize JSON, first check whether the API is missing a resource or Active Model object.

- **Always use a top-level key in the controller**: `render json: { widget: widget }`, not `render json: widget`. This makes the payload self-describing and leaves room for metadata, pagination, and links.
- **Do not put the top-level key in `as_json`**. A single object uses `{ widget: widget }`; a collection uses `{ widgets: widgets }`. The controller owns that wrapper.
- **Define the default resource encoding in `as_json`** on the Active Record or Active Model object. `as_json` describes the object itself, not the full HTTP response.
- Use `:only` / `:except` for fields, `:methods` for computed values, and `:include` for associations. Exclude sensitive/internal fields from the default representation.
- Set default `as_json` options with `||=` so callers can override them intentionally. If you need a second JSON shape, be explicit at the call site and be cautious about creating divergent API contracts.
- Avoid extra serialization frameworks (`jbuilder`, `fast_jsonapi`, custom serializers) unless the default Rails protocol cannot express the response without creating more confusion.

```ruby
class Widget < ApplicationRecord
  def as_json(options = {})
    options[:methods] ||= [:user_facing_identifier]
    options[:except]  ||= [:widget_status_id]
    options[:include] ||= [:widget_status]
    super(options)
  end
end
```

For collection responses, still keep the wrapper at the controller boundary:

```ruby
def index
  widgets = Widget.order(:name)
  render json: { widgets: widgets, count: widgets.size }
end
```

## Content Negotiation

`ApiController`'s `before_action :require_json` uniformly rejects non-JSON requests with 406. Subcontrollers can `skip_before_action :require_json` to support other formats.

## Versioning

- Version number goes in the **URL** (`/api/v1/...`), not the `Accept` header — simple and straightforward.
- Only track major version numbers; backward-compatible changes don't bump the version.
- **Version per-endpoint** — don't upgrade the entire API at once.
- Establish a deprecation policy with enough migration time for clients.

## Testing

```
test/integration/api/v1/widgets_test.rb           # endpoint functionality
test/integration/api/authentication_test.rb       # 401 scenarios
test/integration/api/content_negotiation_test.rb  # 406 scenarios
```

Each API endpoint test should exercise the real authentication/content-negotiation path and assert on the JSON contract:

```ruby
get api_v1_widget_path(widget), headers: {
  "Accept" => "application/json",
  "Authorization" => authorization
}

assert_response :success

parsed_response = JSON.parse(response.body)
refute_nil parsed_response["widget"]
assert_equal widget.name, parsed_response.dig("widget", "name")
assert_equal widget.price_cents, parsed_response.dig("widget", "price_cents")
assert_equal widget.user_facing_identifier, parsed_response.dig("widget", "user_facing_identifier")
assert_equal widget.widget_status.name, parsed_response.dig("widget", "widget_status", "name")
```
