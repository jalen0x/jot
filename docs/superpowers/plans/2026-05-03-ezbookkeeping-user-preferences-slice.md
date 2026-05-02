# ezBookkeeping User Preferences Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first Phase 4 user preference seam by letting each signed-in user save a default currency and using that default on new account forms.

**Architecture:** Store preferences in a one-to-one `UserPreference` model instead of adding more columns to Devise's `users` table. Keep the controller as the HTTP boundary, keep validation in the model, and let `AccountsController` read the user's saved default currency with a simple `USD` fallback for users who have not configured preferences yet.

**Tech Stack:** Rails 8.1, PostgreSQL `structure.sql`, Devise, Pundit, Minitest, FactoryBot, Flowbite semantic Tailwind classes.

---

## File Structure

- Create `db/migrate/20260503130000_create_user_preferences.rb`: user-owned one-to-one preference table.
- Create `app/models/user_preference.rb`: normalization and currency validation.
- Modify `app/models/user.rb`: `has_one :user_preference` association.
- Create `app/policies/user_preference_policy.rb`: signed-in user may show/update their own preference resource.
- Create `app/controllers/user_preferences_controller.rb`: `show` and `update` preference form boundary.
- Create `app/views/user_preferences/show.html.erb`: preference form.
- Modify `config/routes.rb`: add singleton `resource :user_preference, only: [:show, :update]`.
- Modify `app/views/layouts/application.html.erb`: add signed-in `Preferences` nav link.
- Modify `app/controllers/accounts_controller.rb`: use saved default currency on `new`.
- Create `test/models/user_preference_test.rb`: validation/normalization and ownership checks.
- Create `test/integration/user_preferences_test.rb`: auth, update, invalid input, account default behavior.

---

### Task 1: Add UserPreference model and table

**Files:**
- Create: `db/migrate/20260503130000_create_user_preferences.rb`
- Create: `app/models/user_preference.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/user_preference_test.rb`

- [ ] **Step 1: Write the failing model tests**

Create `test/models/user_preference_test.rb`:

```ruby
require "test_helper"

class UserPreferenceTest < ActiveSupport::TestCase
  test "normalizes the default currency code" do
    preference = UserPreference.new(user: create(:user), default_currency_code: " eur ")

    assert_predicate preference, :valid?, preference.errors.full_messages.to_sentence
    assert_equal "EUR", preference.default_currency_code
  end

  test "requires a three-letter default currency code" do
    preference = UserPreference.new(user: create(:user), default_currency_code: "US")

    refute_predicate preference, :valid?
    assert_includes preference.errors[:default_currency_code], "is invalid"
  end

  test "allows only one preference record per user" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    duplicate = UserPreference.new(user: user, default_currency_code: "EUR")

    refute_predicate duplicate, :valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end
end
```

- [ ] **Step 2: Run model tests to verify RED**

Run: `mise exec -- bin/rails test test/models/user_preference_test.rb`

Expected: FAIL with `uninitialized constant UserPreference`.

- [ ] **Step 3: Add migration, model, and association**

Create `db/migrate/20260503130000_create_user_preferences.rb`:

```ruby
class CreateUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_preferences, comment: "User-owned display and ledger defaults" do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }, comment: "Owner of these preferences"
      t.text :default_currency_code, null: false, default: "USD", comment: "ISO 4217 default currency code for new ledger records"
      t.timestamps null: false
    end

    add_check_constraint :user_preferences, "char_length(default_currency_code) = 3", name: "user_preferences_default_currency_code_length"
  end
end
```

Create `app/models/user_preference.rb`:

```ruby
class UserPreference < ApplicationRecord
  belongs_to :user

  normalizes :default_currency_code, with: ->(currency) { currency.to_s.strip.upcase }

  validates :default_currency_code, format: { with: /\A[A-Z]{3}\z/ }
  validates :user_id, uniqueness: true
end
```

Modify `app/models/user.rb`:

```ruby
has_one :user_preference, dependent: :restrict_with_error
```

Place it near the other user-owned associations.

- [ ] **Step 4: Migrate and verify model tests GREEN**

Run: `mise exec -- bin/rails db:migrate`

Expected: creates `user_preferences` and updates `db/structure.sql`.

Run: `mise exec -- bin/rails test test/models/user_preference_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit model slice**

```bash
git add db/migrate/20260503130000_create_user_preferences.rb db/structure.sql app/models/user.rb app/models/user_preference.rb test/models/user_preference_test.rb
git commit -m "feat: add user preferences"
```

---

### Task 2: Add preference settings page and account default currency behavior

**Files:**
- Create: `test/integration/user_preferences_test.rb`
- Create: `app/policies/user_preference_policy.rb`
- Create: `app/controllers/user_preferences_controller.rb`
- Create: `app/views/user_preferences/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/controllers/accounts_controller.rb`

- [ ] **Step 1: Write failing integration tests**

Create `test/integration/user_preferences_test.rb`:

```ruby
require "test_helper"

class UserPreferencesTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get user_preference_path

    assert_redirected_to new_user_session_path
  end

  test "updates the signed-in user's default currency" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "eur"
      }
    }

    assert_redirected_to user_preference_path
    follow_redirect!
    assert_match(/Preferences updated/i, response.body)
    assert_equal "EUR", user.reload.user_preference.default_currency_code
  end

  test "renders validation errors for an invalid currency" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "EURO"
      }
    }

    assert_response :unprocessable_content
    assert_match(/Default currency code is invalid/i, response.body)
  end

  test "uses saved default currency for new accounts" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "CNY")
    sign_in user

    get new_account_path

    assert_response :success
    assert_match(/value="CNY"/, response.body)
  end
end
```

- [ ] **Step 2: Run integration tests to verify RED**

Run: `mise exec -- bin/rails test test/integration/user_preferences_test.rb`

Expected: FAIL with missing route helper such as `undefined local variable or method 'user_preference_path'`.

- [ ] **Step 3: Add policy, controller, route, nav, view, and account default**

Create `app/policies/user_preference_policy.rb`:

```ruby
class UserPreferencePolicy < ApplicationPolicy
  def show? = user.present?
  def update? = user.present?
end
```

Create `app/controllers/user_preferences_controller.rb`:

```ruby
class UserPreferencesController < ApplicationController
  before_action :authenticate_user!

  # GET /user_preference
  def show
    authorize :user_preference
    @user_preference = find_or_build_preference
  end

  # PATCH /user_preference
  def update
    authorize :user_preference
    @user_preference = find_or_build_preference

    if @user_preference.update(user_preference_params)
      redirect_to user_preference_path, notice: "Preferences updated."
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def find_or_build_preference
    current_user.user_preference || current_user.build_user_preference(default_currency_code: "USD")
  end

  def user_preference_params
    params.expect(user_preference: [ :default_currency_code ])
  end
end
```

Add to `config/routes.rb` near singleton resources:

```ruby
resource :user_preference, only: [ :show, :update ]
```

Add a signed-in navigation link in `app/views/layouts/application.html.erb`:

```erb
<%= link_to "Preferences", user_preference_path, class: "text-sm font-medium text-body hover:text-heading" %>
```

Create `app/views/user_preferences/show.html.erb`:

```erb
<% content_for :title, "Preferences" %>

<section class="max-w-2xl space-y-8">
  <div class="space-y-3">
    <p class="text-sm font-medium uppercase tracking-wide text-fg-brand">Settings</p>
    <h1 class="text-3xl font-semibold tracking-tight text-heading">Preferences</h1>
    <p class="text-body">Choose defaults used by new ledger records.</p>
  </div>

  <%= form_with model: @user_preference, url: user_preference_path, class: "bg-neutral-primary-soft border border-default rounded-base p-6 shadow-xs space-y-5" do |form| %>
    <% if @user_preference.errors.any? %>
      <div class="rounded-base border border-danger bg-neutral-primary p-4 text-sm text-danger">
        <p class="font-medium">Preferences could not be saved.</p>
        <ul class="mt-2 list-disc ps-5">
          <% @user_preference.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <div>
      <%= form.label :default_currency_code, "Default currency code", class: "mb-2 block text-sm font-medium text-heading" %>
      <%= form.text_field :default_currency_code, required: true, maxlength: 3, class: "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>
      <p class="mt-2 text-sm text-body-subtle">Used as the starting currency on new account forms.</p>
    </div>

    <div class="flex justify-end gap-3">
      <%= render(ButtonComponent.new(variant: :secondary, href: dashboard_path)) { "Cancel" } %>
      <%= render(ButtonComponent.new(type: :submit, data: { turbo_submits_with: "Saving..." })) { "Save preferences" } %>
    </div>
  <% end %>
</section>
```

Modify `app/controllers/accounts_controller.rb` `default_account_attributes` to use a helper:

```ruby
currency_code: default_currency_code,
```

Add the helper below `next_display_order`:

```ruby
  def default_currency_code
    current_user.user_preference&.default_currency_code || "USD"
  end
```

- [ ] **Step 4: Run integration tests to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/user_preferences_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit HTTP/UI slice**

```bash
git add app/controllers/user_preferences_controller.rb app/policies/user_preference_policy.rb app/views/user_preferences/show.html.erb app/controllers/accounts_controller.rb app/views/layouts/application.html.erb config/routes.rb test/integration/user_preferences_test.rb
git commit -m "feat: add user preference settings"
```

---

### Task 3: Verify user-preferences slice

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/models/user_preference_test.rb test/integration/user_preferences_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop db/migrate/20260503130000_create_user_preferences.rb app/models/user.rb app/models/user_preference.rb app/controllers/user_preferences_controller.rb app/policies/user_preference_policy.rb app/controllers/accounts_controller.rb test/models/user_preference_test.rb test/integration/user_preferences_test.rb`

Expected: PASS.

Run: `mise exec -- bundle exec erb_lint app/views/user_preferences/show.html.erb app/views/layouts/application.html.erb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: implements the first Phase 4 user preference artifact and wires saved default currency into account creation. It intentionally does not add every source display preference yet; locale, date formats, currency display format, default account, and first-day-of-week remain future preference slices.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: the plan consistently uses `UserPreference`, `default_currency_code`, `user_preference_path`, and `current_user.user_preference`.
