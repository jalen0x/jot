# ezBookkeeping Transaction Picture API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add token-authenticated JSON endpoints to upload, list, and delete Active Storage pictures for an owned kept transaction.

**Architecture:** Use nested Rails API routes under `Api::V1::TransactionsController` so every picture operation starts from a transaction scoped through `policy_scope(Transaction).kept`. Keep the controller thin: route/auth/scope in the controller, Active Storage attachment and purge through the transaction association, and JSON response shaping in small private serializer methods. This slice intentionally does not implement legacy ezBookkeeping pre-uploaded unused picture IDs, public download token URLs, image validation, direct uploads, or transaction update endpoints.

**Tech Stack:** Rails 8.1, Active Storage, Pundit, HTTP token auth via `ApiController`, Minitest integration tests.

---

## File Map

- Modify `config/routes.rb`: add nested `pictures` API routes under `api/v1/transactions`.
- Create `app/controllers/api/v1/transaction_pictures_controller.rb`: list, upload, and purge one picture for an owned transaction.
- Modify `app/policies/transaction_policy.rb`: add owner-scoped `show?` and `update?` predicates for nested read/mutation authorization.
- Modify `test/integration/api/v1/transactions_test.rb`: add API coverage for upload/list/delete and cross-user scoping.

## Regression Risks Covered

- API clients can attach receipts to an existing transaction without using HTML forms.
- API clients can enumerate only metadata for pictures on their own kept transactions.
- API clients can purge one picture without deleting the transaction or another user's attachment.
- Another user's transaction picture route returns `404` because the parent transaction is owner-scoped before any attachment lookup.

---

### Task 1: Add Failing API Tests

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add upload/list/delete tests**

Add three tests near the existing transaction delete tests:

```ruby
test "uploads and lists pictures for a token owner's transaction" do
  user = create(:user)
  account = create_account(user: user, name: "Checking")
  category = create_category(user: user, name: "Food", category_type: :expense)
  transaction = create_transaction(
    user: user,
    account: account,
    category: category,
    transaction_kind: :expense,
    transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
    source_amount_cents: 1_250,
    comment: "Lunch"
  )
  raw_token = issue_token(user)

  post api_v1_transaction_pictures_path(transaction),
    params: { picture: fixture_file_upload("receipt.txt", "text/plain") },
    headers: json_headers(raw_token)

  assert_response :created
  attachment = transaction.pictures.attachments.sole
  body = JSON.parse(response.body)
  picture_json = body.fetch("picture")
  assert_equal attachment.id, picture_json.fetch("id")
  assert_equal "receipt.txt", picture_json.fetch("filename")
  assert_equal "text/plain", picture_json.fetch("content_type")
  assert_equal attachment.byte_size, picture_json.fetch("byte_size")
  assert_match(%r{/rails/active_storage/blobs/}, picture_json.fetch("url"))
  refute_includes picture_json.keys, "user_id"

  get api_v1_transaction_pictures_path(transaction), headers: json_headers(raw_token)

  assert_response :success
  pictures = JSON.parse(response.body).fetch("pictures")
  assert_equal [ attachment.id ], pictures.map { |picture| picture.fetch("id") }
end

test "deletes one picture for the token owner's transaction" do
  user = create(:user)
  transaction = create_transaction(
    user: user,
    account: create_account(user: user, name: "Checking"),
    category: create_category(user: user, name: "Food", category_type: :expense),
    transaction_kind: :expense,
    transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
    source_amount_cents: 1_250,
    comment: "Lunch"
  )
  transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
  attachment = transaction.pictures.attachments.sole
  blob = attachment.blob
  raw_token = issue_token(user)

  delete api_v1_transaction_picture_path(transaction, attachment), headers: json_headers(raw_token)

  assert_response :no_content
  assert_empty response.body
  assert_empty transaction.reload.pictures.attachments
  assert_not ActiveStorage::Blob.exists?(blob.id)
end

test "does not list another user's transaction pictures" do
  user = create(:user)
  other_user = create(:user)
  transaction = create_transaction(
    user: other_user,
    account: create_account(user: other_user, name: "Other Checking"),
    category: create_category(user: other_user, name: "Other Food", category_type: :expense),
    transaction_kind: :expense,
    transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
    source_amount_cents: 1_250,
    comment: "Other Lunch"
  )
  transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
  raw_token = issue_token(user)

  get api_v1_transaction_pictures_path(transaction), headers: json_headers(raw_token)

  assert_response :not_found
  assert_predicate transaction.reload.pictures, :attached?
end
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: FAIL because `api_v1_transaction_pictures_path` and `api_v1_transaction_picture_path` do not exist.

---

### Task 2: Add Routes, Authorization, And Controller

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/policies/transaction_policy.rb`
- Create: `app/controllers/api/v1/transaction_pictures_controller.rb`

- [ ] **Step 1: Add nested API routes**

Change `config/routes.rb` API transactions route from:

```ruby
resources :transactions, only: [ :index, :create, :destroy ]
```

to:

```ruby
resources :transactions, only: [ :index, :create, :destroy ] do
  resources :pictures, controller: "transaction_pictures", only: [ :index, :create, :destroy ]
end
```

- [ ] **Step 2: Add policy predicates**

Update `app/policies/transaction_policy.rb` so owner checks are reusable:

```ruby
class TransactionPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = owns_record?
  def new? = create?
  def create? = user.present?
  def update? = owns_record?
  def destroy? = owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end

  private

  def owns_record? = user.present? && record.user_id == user.id
end
```

- [ ] **Step 3: Add picture controller**

Create `app/controllers/api/v1/transaction_pictures_controller.rb`:

```ruby
class Api::V1::TransactionPicturesController < ApiController
  before_action :set_transaction

  # GET /api/v1/transactions/:transaction_id/pictures
  def index
    authorize @transaction, :show?

    render json: { pictures: @transaction.pictures.attachments.map { |attachment| picture_json(attachment) } }
  end

  # POST /api/v1/transactions/:transaction_id/pictures
  def create
    authorize @transaction, :update?
    @transaction.pictures.attach(picture_attachable)

    render json: { picture: picture_json(@transaction.pictures.attachments.last) }, status: :created
  end

  # DELETE /api/v1/transactions/:transaction_id/pictures/:id
  def destroy
    authorize @transaction, :update?
    attachment = @transaction.pictures.attachments.find(params[:id])
    attachment.purge

    head :no_content
  end

  private

  def set_transaction
    @transaction = policy_scope(Transaction).kept.find(params[:transaction_id])
  end

  def picture_attachable
    file = params.expect(:picture)
    return file unless file.respond_to?(:tempfile)

    {
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type,
      identify: false
    }
  end

  def picture_json(attachment)
    {
      id: attachment.id,
      filename: attachment.filename.to_s,
      content_type: attachment.content_type,
      byte_size: attachment.byte_size,
      url: rails_blob_path(attachment, only_path: true)
    }
  end
end
```

- [ ] **Step 4: Run focused tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: PASS.

---

### Task 3: Verify And Commit

**Files:**
- All changed files from Tasks 1-2

- [ ] **Step 1: Run focused API tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run:

```bash
mise exec -- bin/rails test
```

Expected: PASS.

- [ ] **Step 3: Run RuboCop on touched Ruby files**

Run:

```bash
mise exec -- bin/rubocop app/controllers/api/v1/transaction_pictures_controller.rb app/policies/transaction_policy.rb test/integration/api/v1/transactions_test.rb config/routes.rb
```

Expected: no offenses.

- [ ] **Step 4: Commit the implementation**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/transaction_pictures_controller.rb app/policies/transaction_policy.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction picture api endpoints"
```

---

## Self-Review

- Spec coverage: Implements the Phase 6 Active Storage upload/removal ownership API seam from the rewrite design.
- Scope control: Does not implement legacy `.json` pre-upload/remove-unused endpoints, transaction create-by-picture-ids, tokenized protected image downloads, update transaction endpoints, image processing, validation limits, or UI deletion.
- Placeholder scan: No placeholders remain.
