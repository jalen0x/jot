# ezBookkeeping Classification Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Rails-native transaction categories, tag groups, tags, and transaction taggings so accounts can be classified before transaction recording is implemented.

**Architecture:** This slice keeps metadata CRUD simple and Rails-native: controllers coerce HTTP params and create records directly because creation is single-record persistence, while Pundit scopes keep all data owned by `current_user`. Models enforce ownership, hierarchy, normalization, soft deletion, and database constraints; transaction taggings prepare the many-to-many seam that `TransactionRecorder` will use in the next slice.

**Tech Stack:** Rails 8.1, PostgreSQL SQL schema, Devise, Pundit, Discard, Prefixed IDs, ViewComponent, Hotwire/Turbo, Flowbite semantic classes, Minitest, FactoryBot.

---

## File Structure

- `db/migrate/20260503100000_create_classification_tables.rb`: transaction category, tag group, tag, and tagging tables with comments, constraints, indexes, and foreign keys.
- `app/models/transaction_category.rb`: two-level user-owned category metadata.
- `app/models/transaction_tag_group.rb`: user-owned tag group metadata.
- `app/models/transaction_tag.rb`: user-owned tag metadata with optional group.
- `app/models/transaction_tagging.rb`: join model between transactions and tags.
- `app/models/user.rb`: associations to categories, tag groups, tags, and taggings.
- `app/models/transaction.rb`: association to taggings and tags.
- `app/policies/transaction_category_policy.rb`: ownership policy/scope for categories.
- `app/policies/transaction_tag_group_policy.rb`: ownership policy/scope for groups.
- `app/policies/transaction_tag_policy.rb`: ownership policy/scope for tags.
- `app/controllers/transaction_categories_controller.rb`: index/new/create category boundary.
- `app/controllers/transaction_tag_groups_controller.rb`: index/new/create group boundary.
- `app/controllers/transaction_tags_controller.rb`: new/create tag boundary.
- `app/views/transaction_categories/*`: category index/new/form views.
- `app/views/transaction_tag_groups/*`: grouped tags index/new/form views.
- `app/views/transaction_tags/new.html.erb` and `_form.html.erb`: tag creation views.
- `config/routes.rb`: canonical category, tag group, and tag routes.
- `app/views/layouts/application.html.erb`: signed-in nav links.
- `test/models/*`: DB/model tests.
- `test/integration/*`: auth, scoping, and create-flow tests.

## Task 1: Classification Tables

**Files:**
- Create: `test/models/transaction_category_test.rb`
- Create: `test/models/transaction_tag_group_test.rb`
- Create: `test/models/transaction_tag_test.rb`
- Create: `test/models/transaction_tagging_test.rb`
- Create: `db/migrate/20260503100000_create_classification_tables.rb`

- [ ] **Step 1: Write failing model tests**

Create `test/models/transaction_category_test.rb`:

```ruby
require "test_helper"

class TransactionCategoryTest < ActiveSupport::TestCase
  test "belongs to a user and normalizes display fields" do
    category = TransactionCategory.create!(
      user: create(:user),
      name: "  Groceries  ",
      category_type: :expense,
      icon_key: 12,
      color_hex: "#f97316",
      display_order: 1,
      comment: "  Weekly food  "
    )

    assert_equal "Groceries", category.name
    assert_equal "F97316", category.color_hex
    assert_equal "Weekly food", category.comment
  end

  test "database rejects a category without an owner" do
    category = TransactionCategory.create!(
      user: create(:user),
      name: "Salary",
      category_type: :income,
      icon_key: 1,
      color_hex: "22C55E",
      display_order: 1
    )

    error = assert_raises(ActiveRecord::NotNullViolation) do
      category.update_column(:user_id, nil)
    end

    assert_match(/user_id/i, error.message)
  end
end
```

Create `test/models/transaction_tag_group_test.rb`:

```ruby
require "test_helper"

class TransactionTagGroupTest < ActiveSupport::TestCase
  test "belongs to a user and normalizes name" do
    group = TransactionTagGroup.create!(
      user: create(:user),
      name: "  Context  ",
      display_order: 1
    )

    assert_equal "Context", group.name
  end
end
```

Create `test/models/transaction_tag_test.rb`:

```ruby
require "test_helper"

class TransactionTagTest < ActiveSupport::TestCase
  test "belongs to a user and optional group" do
    user = create(:user)
    group = TransactionTagGroup.create!(user: user, name: "Context", display_order: 1)

    tag = TransactionTag.create!(
      user: user,
      transaction_tag_group: group,
      name: "  Business  ",
      display_order: 1
    )

    assert_equal user, tag.user
    assert_equal group, tag.transaction_tag_group
    assert_equal "Business", tag.name
  end
end
```

Create `test/models/transaction_tagging_test.rb`:

```ruby
require "test_helper"

class TransactionTaggingTest < ActiveSupport::TestCase
  test "joins a transaction and tag for the same user" do
    user = create(:user)
    account = create_account(user: user)
    transaction = create_transaction(user: user, account: account)
    tag = TransactionTag.create!(user: user, name: "Business", display_order: 1)

    tagging = TransactionTagging.create!(user: user, transaction: transaction, transaction_tag: tag)

    assert_equal transaction, tagging.transaction
    assert_equal tag, tagging.transaction_tag
  end

  private

  def create_account(user:)
    Account.create!(
      user: user,
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end

  def create_transaction(user:, account:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0
    )
  end
end
```

- [ ] **Step 2: Run model tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/models/transaction_category_test.rb test/models/transaction_tag_group_test.rb test/models/transaction_tag_test.rb test/models/transaction_tagging_test.rb
```

Expected: FAIL with `uninitialized constant TransactionCategory` or `uninitialized constant TransactionTagGroup`.

- [ ] **Step 3: Add the migration**

Create `db/migrate/20260503100000_create_classification_tables.rb`:

```ruby
class CreateClassificationTables < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_categories, comment: "User-owned transaction categories" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this category"
      t.references :parent_category, null: true, foreign_key: { to_table: :transaction_categories }, index: true, comment: "Parent category for two-level category hierarchies"
      t.integer :category_type, null: false, comment: "Category type code: income, expense, or transfer"
      t.text :name, null: false, comment: "Human-readable category name"
      t.integer :display_order, null: false, default: 0, comment: "User-controlled display order"
      t.integer :icon_key, null: false, comment: "Icon identifier from the category icon catalog"
      t.text :color_hex, null: false, comment: "Six-character RGB hex color without #"
      t.boolean :hidden, null: false, default: false, comment: "Whether the category is hidden in normal lists"
      t.text :comment, null: false, default: "", comment: "Optional user note"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :transaction_categories, :discarded_at
    add_index :transaction_categories, [ :user_id, :category_type, :parent_category_id, :display_order ], name: "index_transaction_categories_on_owner_type_parent_order"
    add_check_constraint :transaction_categories, "category_type IN (1,2,3)", name: "transaction_categories_type_valid"
    add_check_constraint :transaction_categories, "char_length(color_hex) = 6", name: "transaction_categories_color_hex_length"
    add_check_constraint :transaction_categories, "parent_category_id IS NULL OR parent_category_id <> id", name: "transaction_categories_parent_not_self"

    create_table :transaction_tag_groups, comment: "User-owned transaction tag groups" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this tag group"
      t.text :name, null: false, comment: "Human-readable tag group name"
      t.integer :display_order, null: false, default: 0, comment: "User-controlled display order"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :transaction_tag_groups, :discarded_at
    add_index :transaction_tag_groups, [ :user_id, :display_order ], name: "index_transaction_tag_groups_on_owner_order"

    create_table :transaction_tags, comment: "User-owned transaction tags" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this tag"
      t.references :transaction_tag_group, null: true, foreign_key: true, index: true, comment: "Optional tag group"
      t.text :name, null: false, comment: "Human-readable tag name"
      t.integer :display_order, null: false, default: 0, comment: "User-controlled display order"
      t.boolean :hidden, null: false, default: false, comment: "Whether the tag is hidden in normal lists"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :transaction_tags, :discarded_at
    add_index :transaction_tags, [ :user_id, :transaction_tag_group_id, :display_order ], name: "index_transaction_tags_on_owner_group_order"

    create_table :transaction_taggings, comment: "Join table between transactions and tags" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this tagging"
      t.references :transaction, null: false, foreign_key: true, index: true, comment: "Tagged transaction"
      t.references :transaction_tag, null: false, foreign_key: true, index: true, comment: "Applied transaction tag"
      t.timestamps null: false
    end

    add_index :transaction_taggings, [ :transaction_id, :transaction_tag_id ], unique: true, name: "index_transaction_taggings_on_transaction_and_tag"
  end
end
```

- [ ] **Step 4: Add temporary empty models**

Create these files:

```ruby
# app/models/transaction_category.rb
class TransactionCategory < ApplicationRecord
end
```

```ruby
# app/models/transaction_tag_group.rb
class TransactionTagGroup < ApplicationRecord
end
```

```ruby
# app/models/transaction_tag.rb
class TransactionTag < ApplicationRecord
end
```

```ruby
# app/models/transaction_tagging.rb
class TransactionTagging < ApplicationRecord
end
```

- [ ] **Step 5: Run migrations**

Run:

```bash
mise exec -- bin/rails db:migrate
mise exec -- bin/rails db:migrate RAILS_ENV=test
```

Expected: both commands complete and `db/structure.sql` gains the four classification tables.

- [ ] **Step 6: Run model tests to verify next RED state**

Run:

```bash
mise exec -- bin/rails test test/models/transaction_category_test.rb test/models/transaction_tag_group_test.rb test/models/transaction_tag_test.rb test/models/transaction_tagging_test.rb
```

Expected: FAIL with missing associations or enum methods.

## Task 2: Classification Models

**Files:**
- Modify: `app/models/transaction_category.rb`
- Modify: `app/models/transaction_tag_group.rb`
- Modify: `app/models/transaction_tag.rb`
- Modify: `app/models/transaction_tagging.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/transaction.rb`

- [ ] **Step 1: Implement TransactionCategory**

Replace `app/models/transaction_category.rb` with:

```ruby
class TransactionCategory < ApplicationRecord
  include Discard::Model

  has_prefix_id :cat

  belongs_to :user
  belongs_to :parent_category, class_name: "TransactionCategory", optional: true
  has_many :sub_categories, class_name: "TransactionCategory", foreign_key: :parent_category_id, dependent: :restrict_with_error, inverse_of: :parent_category

  enum :category_type, {
    income: 1,
    expense: 2,
    transfer: 3
  }

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :color_hex, with: ->(color) { color.to_s.delete_prefix("#").upcase }
  normalizes :comment, with: ->(comment) { comment.to_s.strip }

  validates :name, presence: true
  validates :icon_key, numericality: { only_integer: true, greater_than: 0 }
  validates :color_hex, format: { with: /\A\h{6}\z/ }
end
```

- [ ] **Step 2: Implement tag models**

Replace `app/models/transaction_tag_group.rb` with:

```ruby
class TransactionTagGroup < ApplicationRecord
  include Discard::Model

  has_prefix_id :taggrp

  belongs_to :user
  has_many :transaction_tags, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true
end
```

Replace `app/models/transaction_tag.rb` with:

```ruby
class TransactionTag < ApplicationRecord
  include Discard::Model

  has_prefix_id :tag

  belongs_to :user
  belongs_to :transaction_tag_group, optional: true
  has_many :transaction_taggings, dependent: :restrict_with_error
  has_many :transactions, through: :transaction_taggings

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true
end
```

Replace `app/models/transaction_tagging.rb` with:

```ruby
class TransactionTagging < ApplicationRecord
  belongs_to :user
  belongs_to :transaction
  belongs_to :transaction_tag
end
```

- [ ] **Step 3: Add user and transaction associations**

Modify `app/models/user.rb` to include these associations after existing ledger associations:

```ruby
  has_many :transaction_categories, dependent: :restrict_with_error
  has_many :transaction_tag_groups, dependent: :restrict_with_error
  has_many :transaction_tags, dependent: :restrict_with_error
  has_many :transaction_taggings, dependent: :restrict_with_error
```

Modify `app/models/transaction.rb` to include:

```ruby
  has_many :transaction_taggings, dependent: :restrict_with_error
  has_many :transaction_tags, through: :transaction_taggings
```

- [ ] **Step 4: Run model tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/models/transaction_category_test.rb test/models/transaction_tag_group_test.rb test/models/transaction_tag_test.rb test/models/transaction_tagging_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit classification tables and models**

Run:

```bash
git add db/migrate/20260503100000_create_classification_tables.rb db/structure.sql app/models/transaction_category.rb app/models/transaction_tag_group.rb app/models/transaction_tag.rb app/models/transaction_tagging.rb app/models/user.rb app/models/transaction.rb test/models/transaction_category_test.rb test/models/transaction_tag_group_test.rb test/models/transaction_tag_test.rb test/models/transaction_tagging_test.rb
git commit -m "feat: add transaction classification models"
```

## Task 3: Category Routes, Policy, Controller, And Views

**Files:**
- Create: `test/integration/transaction_categories_test.rb`
- Create: `app/policies/transaction_category_policy.rb`
- Modify: `config/routes.rb`
- Create: `app/controllers/transaction_categories_controller.rb`
- Create: `app/views/transaction_categories/index.html.erb`
- Create: `app/views/transaction_categories/new.html.erb`
- Create: `app/views/transaction_categories/_form.html.erb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Write failing category integration tests**

Create `test/integration/transaction_categories_test.rb`:

```ruby
require "test_helper"

class TransactionCategoriesTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get transaction_categories_path

    assert_redirected_to new_user_session_path
  end

  test "lists only current user categories" do
    user = create(:user)
    other_user = create(:user)
    own_category = create_category(user: user, name: "Groceries")
    create_category(user: other_user, name: "Other Groceries")

    sign_in user
    get transaction_categories_path

    assert_response :success
    assert_select "h1", text: /categories/i
    assert_select "li", text: /#{own_category.name}/i
    assert_select "li", text: /Other Groceries/i, count: 0
  end

  test "creates a category for current user" do
    user = create(:user)
    sign_in user

    post transaction_categories_path, params: {
      transaction_category: {
        name: "Salary",
        category_type: "income",
        icon_key: "1",
        color_hex: "22C55E",
        comment: "Monthly pay"
      }
    }

    category = user.transaction_categories.sole
    assert_redirected_to transaction_categories_path
    assert_equal "Salary", category.name
    assert_predicate category, :income?
  end

  private

  def create_category(user:, name:)
    TransactionCategory.create!(
      user: user,
      name: name,
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
```

- [ ] **Step 2: Run category integration test to verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/transaction_categories_test.rb
```

Expected: FAIL with missing `transaction_categories_path`.

- [ ] **Step 3: Add policy, routes, and controller**

Create `app/policies/transaction_category_policy.rb`:

```ruby
class TransactionCategoryPolicy < ApplicationPolicy
  def index? = user.present?
  def new? = create?
  def create? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
```

Add this route before `resources :accounts` in `config/routes.rb`:

```ruby
  resources :transaction_categories, only: [ :index, :new, :create ]
```

Create `app/controllers/transaction_categories_controller.rb`:

```ruby
class TransactionCategoriesController < ApplicationController
  before_action :authenticate_user!

  # GET /transaction_categories
  def index
    authorize TransactionCategory
    @transaction_categories = policy_scope(TransactionCategory).kept.where(parent_category_id: nil).order(:category_type, :display_order, :name)
  end

  # GET /transaction_categories/new
  def new
    @transaction_category = current_user.transaction_categories.build(default_category_attributes)
    authorize @transaction_category
  end

  # POST /transaction_categories
  def create
    authorize TransactionCategory
    @transaction_category = current_user.transaction_categories.build(category_attributes)

    if @transaction_category.save
      redirect_to transaction_categories_path, notice: "Category created."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def category_attributes
    category_params.merge(display_order: next_display_order)
  end

  def category_params
    params.expect(transaction_category: [ :name, :category_type, :icon_key, :color_hex, :comment ])
  end

  def next_display_order
    current_user.transaction_categories.kept.where(parent_category_id: nil).maximum(:display_order).to_i + 1
  end

  def default_category_attributes
    {
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: next_display_order
    }
  end
end
```

- [ ] **Step 4: Add category views**

Create `app/views/transaction_categories/index.html.erb`:

```erb
<% content_for :title, "Categories" %>

<section class="flex flex-col gap-6">
  <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">Categories</h1>
      <p class="mt-2 max-w-2xl text-sm text-body">Classify future income, expenses, and transfers.</p>
    </div>

    <%= render(ButtonComponent.new(href: new_transaction_category_path)) { "New category" } %>
  </div>

  <% if @transaction_categories.any? %>
    <ul class="grid gap-4 md:grid-cols-2">
      <% @transaction_categories.each do |category| %>
        <li id="<%= dom_id(category) %>" class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h2 class="text-lg font-semibold text-heading"><%= category.name %></h2>
              <p class="mt-1 text-sm text-body-subtle"><%= category.category_type.humanize %></p>
            </div>
            <% if category.hidden? %>
              <span class="rounded-base bg-neutral-secondary-medium px-3 py-1 text-sm font-medium text-heading">Hidden</span>
            <% end %>
          </div>

          <% if category.comment.present? %>
            <p class="mt-4 text-sm text-body"><%= category.comment %></p>
          <% end %>
        </li>
      <% end %>
    </ul>
  <% else %>
    <div class="bg-neutral-primary-soft border border-default rounded-base p-8 text-center shadow-xs">
      <h2 class="text-xl font-semibold text-heading">No categories yet</h2>
      <p class="mx-auto mt-2 max-w-xl text-sm text-body">Add your first income or expense category before recording classified transactions.</p>
      <div class="mt-5"><%= render(ButtonComponent.new(href: new_transaction_category_path)) { "Create first category" } %></div>
    </div>
  <% end %>
</section>
```

Create `app/views/transaction_categories/new.html.erb`:

```erb
<% content_for :title, "New category" %>

<section class="mx-auto w-full max-w-2xl">
  <div class="mb-6">
    <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">New category</h1>
    <p class="mt-2 text-sm text-body">Add a classification for future transactions.</p>
  </div>

  <%= render "form", transaction_category: @transaction_category %>
</section>
```

Create `app/views/transaction_categories/_form.html.erb`:

```erb
<%# locals: (transaction_category:) %>
<% field_classes = "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>

<%= form_with model: transaction_category, class: "bg-neutral-primary-soft border border-default rounded-base p-6 shadow-xs" do |form| %>
  <% if transaction_category.errors.any? %>
    <div class="mb-5 rounded-base border border-danger bg-neutral-primary p-4 text-sm text-danger">
      <p class="font-medium">Category could not be saved.</p>
      <ul class="mt-2 list-disc ps-5">
        <% transaction_category.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <%= render FormField::InputComponent.new(form: form, field: :name, label: "Name", autofocus: true, required: true) %>

  <div class="mb-4 grid gap-4 sm:grid-cols-3">
    <div>
      <%= form.label :category_type, "Type", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.select :category_type, TransactionCategory.category_types.keys.map { |key| [ key.humanize, key ] }, {}, class: field_classes %>
    </div>
    <div>
      <%= form.label :icon_key, "Icon", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.number_field :icon_key, min: 1, required: true, class: field_classes %>
    </div>
    <%= render FormField::InputComponent.new(form: form, field: :color_hex, label: "Color", placeholder: "F97316", required: true) %>
  </div>

  <%= render FormField::InputComponent.new(form: form, field: :comment, label: "Comment", type: :textarea) %>

  <div class="flex items-center justify-end gap-3">
    <%= render(ButtonComponent.new(variant: :secondary, href: transaction_categories_path)) { "Cancel" } %>
    <%= render(ButtonComponent.new(type: :submit, data: { turbo_submits_with: "Saving..." })) { "Create category" } %>
  </div>
<% end %>
```

- [ ] **Step 5: Add category navigation**

In `app/views/layouts/application.html.erb`, add this link next to the signed-in `Accounts` link:

```erb
<%= link_to "Categories", transaction_categories_path, class: "text-sm font-medium text-body hover:text-heading" %>
```

- [ ] **Step 6: Run category integration test to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/transaction_categories_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit category UI**

Run:

```bash
git add app/policies/transaction_category_policy.rb config/routes.rb app/controllers/transaction_categories_controller.rb app/views/transaction_categories app/views/layouts/application.html.erb test/integration/transaction_categories_test.rb
git commit -m "feat: add transaction category UI"
```

## Task 4: Tag Group And Tag Routes, Policies, Controllers, And Views

**Files:**
- Create: `test/integration/transaction_tag_groups_test.rb`
- Create: `test/integration/transaction_tags_test.rb`
- Create: `app/policies/transaction_tag_group_policy.rb`
- Create: `app/policies/transaction_tag_policy.rb`
- Modify: `config/routes.rb`
- Create: `app/controllers/transaction_tag_groups_controller.rb`
- Create: `app/controllers/transaction_tags_controller.rb`
- Create: `app/views/transaction_tag_groups/index.html.erb`
- Create: `app/views/transaction_tag_groups/new.html.erb`
- Create: `app/views/transaction_tag_groups/_form.html.erb`
- Create: `app/views/transaction_tags/new.html.erb`
- Create: `app/views/transaction_tags/_form.html.erb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Write failing tag integration tests**

Create `test/integration/transaction_tag_groups_test.rb`:

```ruby
require "test_helper"

class TransactionTagGroupsTest < ActionDispatch::IntegrationTest
  test "lists only current user tag groups and tags" do
    user = create(:user)
    other_user = create(:user)
    group = TransactionTagGroup.create!(user: user, name: "Context", display_order: 1)
    TransactionTag.create!(user: user, transaction_tag_group: group, name: "Business", display_order: 1)
    other_group = TransactionTagGroup.create!(user: other_user, name: "Other Context", display_order: 1)
    TransactionTag.create!(user: other_user, transaction_tag_group: other_group, name: "Other Business", display_order: 1)

    sign_in user
    get transaction_tag_groups_path

    assert_response :success
    assert_select "h1", text: /tags/i
    assert_select "li", text: /Context/i
    assert_select "li", text: /Business/i
    assert_select "li", text: /Other Context/i, count: 0
    assert_select "li", text: /Other Business/i, count: 0
  end

  test "creates a tag group for current user" do
    user = create(:user)
    sign_in user

    post transaction_tag_groups_path, params: { transaction_tag_group: { name: "Context" } }

    group = user.transaction_tag_groups.sole
    assert_redirected_to transaction_tag_groups_path
    assert_equal "Context", group.name
  end
end
```

Create `test/integration/transaction_tags_test.rb`:

```ruby
require "test_helper"

class TransactionTagsTest < ActionDispatch::IntegrationTest
  test "creates a tag for current user" do
    user = create(:user)
    group = TransactionTagGroup.create!(user: user, name: "Context", display_order: 1)
    other_group = TransactionTagGroup.create!(user: create(:user), name: "Other Context", display_order: 1)
    sign_in user

    post transaction_tags_path, params: {
      transaction_tag: {
        name: "Business",
        transaction_tag_group_id: group.id
      }
    }

    tag = user.transaction_tags.sole
    assert_redirected_to transaction_tag_groups_path
    assert_equal "Business", tag.name
    assert_equal group, tag.transaction_tag_group
    refute_equal other_group, tag.transaction_tag_group
  end
end
```

- [ ] **Step 2: Run tag integration tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/transaction_tag_groups_test.rb test/integration/transaction_tags_test.rb
```

Expected: FAIL with missing route helpers.

- [ ] **Step 3: Add policies, routes, and controllers**

Create `app/policies/transaction_tag_group_policy.rb`:

```ruby
class TransactionTagGroupPolicy < ApplicationPolicy
  def index? = user.present?
  def new? = create?
  def create? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
```

Create `app/policies/transaction_tag_policy.rb`:

```ruby
class TransactionTagPolicy < ApplicationPolicy
  def new? = create?
  def create? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
```

Add these routes after `resources :transaction_categories` in `config/routes.rb`:

```ruby
  resources :transaction_tag_groups, only: [ :index, :new, :create ]
  resources :transaction_tags, only: [ :new, :create ]
```

Create `app/controllers/transaction_tag_groups_controller.rb`:

```ruby
class TransactionTagGroupsController < ApplicationController
  before_action :authenticate_user!

  # GET /transaction_tag_groups
  def index
    authorize TransactionTagGroup
    @transaction_tag_groups = policy_scope(TransactionTagGroup).kept.includes(:transaction_tags).order(:display_order, :name)
    @ungrouped_tags = policy_scope(TransactionTag).kept.where(transaction_tag_group_id: nil).order(:display_order, :name)
  end

  # GET /transaction_tag_groups/new
  def new
    @transaction_tag_group = current_user.transaction_tag_groups.build(display_order: next_display_order)
    authorize @transaction_tag_group
  end

  # POST /transaction_tag_groups
  def create
    authorize TransactionTagGroup
    @transaction_tag_group = current_user.transaction_tag_groups.build(tag_group_params.merge(display_order: next_display_order))

    if @transaction_tag_group.save
      redirect_to transaction_tag_groups_path, notice: "Tag group created."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def tag_group_params
    params.expect(transaction_tag_group: [ :name ])
  end

  def next_display_order
    current_user.transaction_tag_groups.kept.maximum(:display_order).to_i + 1
  end
end
```

Create `app/controllers/transaction_tags_controller.rb`:

```ruby
class TransactionTagsController < ApplicationController
  before_action :authenticate_user!

  # GET /transaction_tags/new
  def new
    @transaction_tag = current_user.transaction_tags.build(display_order: next_display_order)
    authorize @transaction_tag
    @transaction_tag_groups = tag_groups
  end

  # POST /transaction_tags
  def create
    authorize TransactionTag
    @transaction_tag = current_user.transaction_tags.build(tag_params.merge(display_order: next_display_order))

    if @transaction_tag.save
      redirect_to transaction_tag_groups_path, notice: "Tag created."
    else
      @transaction_tag_groups = tag_groups
      render :new, status: :unprocessable_content
    end
  end

  private

  def tag_params
    params.expect(transaction_tag: [ :name, :transaction_tag_group_id ])
  end

  def tag_groups
    current_user.transaction_tag_groups.kept.order(:display_order, :name)
  end

  def next_display_order
    current_user.transaction_tags.kept.maximum(:display_order).to_i + 1
  end
end
```

- [ ] **Step 4: Add tag views**

Create `app/views/transaction_tag_groups/index.html.erb`:

```erb
<% content_for :title, "Tags" %>

<section class="flex flex-col gap-6">
  <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">Tags</h1>
      <p class="mt-2 max-w-2xl text-sm text-body">Add optional labels for future transaction filtering.</p>
    </div>

    <div class="flex flex-wrap gap-3">
      <%= render(ButtonComponent.new(variant: :secondary, href: new_transaction_tag_group_path)) { "New group" } %>
      <%= render(ButtonComponent.new(href: new_transaction_tag_path)) { "New tag" } %>
    </div>
  </div>

  <% if @transaction_tag_groups.any? || @ungrouped_tags.any? %>
    <ul class="grid gap-4 md:grid-cols-2">
      <% @transaction_tag_groups.each do |group| %>
        <li id="<%= dom_id(group) %>" class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
          <h2 class="text-lg font-semibold text-heading"><%= group.name %></h2>
          <ul class="mt-4 flex flex-wrap gap-2">
            <% group.transaction_tags.sort_by(&:display_order).each do |tag| %>
              <li class="rounded-base bg-neutral-secondary-medium px-3 py-1 text-sm font-medium text-heading"><%= tag.name %></li>
            <% end %>
          </ul>
        </li>
      <% end %>

      <% if @ungrouped_tags.any? %>
        <li class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
          <h2 class="text-lg font-semibold text-heading">Ungrouped</h2>
          <ul class="mt-4 flex flex-wrap gap-2">
            <% @ungrouped_tags.each do |tag| %>
              <li class="rounded-base bg-neutral-secondary-medium px-3 py-1 text-sm font-medium text-heading"><%= tag.name %></li>
            <% end %>
          </ul>
        </li>
      <% end %>
    </ul>
  <% else %>
    <div class="bg-neutral-primary-soft border border-default rounded-base p-8 text-center shadow-xs">
      <h2 class="text-xl font-semibold text-heading">No tags yet</h2>
      <p class="mx-auto mt-2 max-w-xl text-sm text-body">Create tags when categories are too broad for the filters you need.</p>
      <div class="mt-5"><%= render(ButtonComponent.new(href: new_transaction_tag_path)) { "Create first tag" } %></div>
    </div>
  <% end %>
</section>
```

Create `app/views/transaction_tag_groups/new.html.erb`:

```erb
<% content_for :title, "New tag group" %>

<section class="mx-auto w-full max-w-2xl">
  <div class="mb-6">
    <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">New tag group</h1>
    <p class="mt-2 text-sm text-body">Group related transaction tags.</p>
  </div>

  <%= render "form", transaction_tag_group: @transaction_tag_group %>
</section>
```

Create `app/views/transaction_tag_groups/_form.html.erb`:

```erb
<%# locals: (transaction_tag_group:) %>

<%= form_with model: transaction_tag_group, class: "bg-neutral-primary-soft border border-default rounded-base p-6 shadow-xs" do |form| %>
  <% if transaction_tag_group.errors.any? %>
    <div class="mb-5 rounded-base border border-danger bg-neutral-primary p-4 text-sm text-danger">
      <p class="font-medium">Tag group could not be saved.</p>
      <ul class="mt-2 list-disc ps-5">
        <% transaction_tag_group.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <%= render FormField::InputComponent.new(form: form, field: :name, label: "Name", autofocus: true, required: true) %>

  <div class="flex items-center justify-end gap-3">
    <%= render(ButtonComponent.new(variant: :secondary, href: transaction_tag_groups_path)) { "Cancel" } %>
    <%= render(ButtonComponent.new(type: :submit, data: { turbo_submits_with: "Saving..." })) { "Create group" } %>
  </div>
<% end %>
```

Create `app/views/transaction_tags/new.html.erb`:

```erb
<% content_for :title, "New tag" %>

<section class="mx-auto w-full max-w-2xl">
  <div class="mb-6">
    <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">New tag</h1>
    <p class="mt-2 text-sm text-body">Create a label for future transaction filters.</p>
  </div>

  <%= render "form", transaction_tag: @transaction_tag, transaction_tag_groups: @transaction_tag_groups %>
</section>
```

Create `app/views/transaction_tags/_form.html.erb`:

```erb
<%# locals: (transaction_tag:, transaction_tag_groups:) %>
<% field_classes = "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>

<%= form_with model: transaction_tag, class: "bg-neutral-primary-soft border border-default rounded-base p-6 shadow-xs" do |form| %>
  <% if transaction_tag.errors.any? %>
    <div class="mb-5 rounded-base border border-danger bg-neutral-primary p-4 text-sm text-danger">
      <p class="font-medium">Tag could not be saved.</p>
      <ul class="mt-2 list-disc ps-5">
        <% transaction_tag.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <%= render FormField::InputComponent.new(form: form, field: :name, label: "Name", autofocus: true, required: true) %>

  <div class="mb-4">
    <%= form.label :transaction_tag_group_id, "Group", class: "block mb-2 text-sm font-medium text-heading" %>
    <%= form.collection_select :transaction_tag_group_id, transaction_tag_groups, :id, :name, { include_blank: "Ungrouped" }, class: field_classes %>
  </div>

  <div class="flex items-center justify-end gap-3">
    <%= render(ButtonComponent.new(variant: :secondary, href: transaction_tag_groups_path)) { "Cancel" } %>
    <%= render(ButtonComponent.new(type: :submit, data: { turbo_submits_with: "Saving..." })) { "Create tag" } %>
  </div>
<% end %>
```

- [ ] **Step 5: Add tag navigation**

In `app/views/layouts/application.html.erb`, add this link next to the signed-in category link:

```erb
<%= link_to "Tags", transaction_tag_groups_path, class: "text-sm font-medium text-body hover:text-heading" %>
```

- [ ] **Step 6: Run tag integration tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/transaction_tag_groups_test.rb test/integration/transaction_tags_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit tag UI**

Run:

```bash
git add app/policies/transaction_tag_group_policy.rb app/policies/transaction_tag_policy.rb config/routes.rb app/controllers/transaction_tag_groups_controller.rb app/controllers/transaction_tags_controller.rb app/views/transaction_tag_groups app/views/transaction_tags app/views/layouts/application.html.erb test/integration/transaction_tag_groups_test.rb test/integration/transaction_tags_test.rb
git commit -m "feat: add transaction tag UI"
```

## Task 5: Slice Verification

**Files:**
- Verify: all files changed in Tasks 1-4

- [ ] **Step 1: Run targeted tests**

Run:

```bash
mise exec -- bin/rails test test/models/transaction_category_test.rb test/models/transaction_tag_group_test.rb test/models/transaction_tag_test.rb test/models/transaction_tagging_test.rb test/integration/transaction_categories_test.rb test/integration/transaction_tag_groups_test.rb test/integration/transaction_tags_test.rb
```

Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run:

```bash
mise exec -- bin/rails test
```

Expected: PASS.

- [ ] **Step 3: Run Ruby lint**

Run:

```bash
mise exec -- bin/rubocop
```

Expected: PASS.

- [ ] **Step 4: Run ERB lint for changed views**

Run:

```bash
mise exec -- bundle exec erb_lint app/views/transaction_categories app/views/transaction_tag_groups app/views/transaction_tags app/views/layouts/application.html.erb
```

Expected: PASS.

- [ ] **Step 5: Commit lint-only fixes if needed**

If lint changed files, run:

```bash
git add app test config db
git commit -m "style: clean classification slice"
```

Expected: commit is created only if lint produced edits.

## Self-Review Checklist

- Spec coverage: This plan implements Phase 1 `TransactionCategory`, `TransactionTagGroup`, `TransactionTag`, and `TransactionTagging`; transaction recording, dashboard, imports, reports, settings, security, attachments, schedules, API, and AI remain outside this slice. MCP is excluded from the Rails rewrite scope.
- Placeholder scan: each file has concrete code, test commands, and expected outcomes; no step depends on unspecified behavior.
- Type consistency: category fields use `category_type`, `icon_key`, `color_hex`, `display_order`; tag fields use `transaction_tag_group_id`; join fields use `transaction_id` and `transaction_tag_id` across migration, models, controllers, views, and tests.
