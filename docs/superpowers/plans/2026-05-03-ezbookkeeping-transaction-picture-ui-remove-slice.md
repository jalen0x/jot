# ezBookkeeping Transaction Picture UI Remove Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let signed-in users remove one attached transaction picture from the Rails transactions index without deleting the transaction.

**Architecture:** Add a nested HTML `TransactionPicturesController#destroy` under `resources :transactions`, scope the parent transaction through `policy_scope(Transaction).kept`, authorize with `TransactionPolicy#update?`, and purge only the selected Active Storage attachment. The index view keeps the existing filename badges and adds a small danger `button_to` beside each attached picture. This slice does not add image thumbnails, modal previews, edit transaction forms, JavaScript confirmation modals, or bulk picture management.

**Tech Stack:** Rails 8.1, Active Storage, Pundit, Turbo/Rails `button_to`, ERB, Minitest integration tests, Flowbite semantic classes.

---

## File Map

- Modify `config/routes.rb`: add nested HTML transaction picture destroy route.
- Create `app/controllers/transaction_pictures_controller.rb`: purge one owned transaction attachment and redirect back to `transactions_path`.
- Modify `app/views/transactions/index.html.erb`: render a remove button next to each picture filename.
- Modify `test/integration/transactions_test.rb`: cover the rendered remove control, successful purge, and cross-user protection.

## Regression Risks Covered

- A user can remove one receipt picture without deleting the whole transaction.
- The transactions index exposes a usable remove control for each attached picture.
- A user cannot remove another user's transaction picture through the HTML endpoint.
- Purging a picture removes its Active Storage blob instead of only detaching the row.

---

### Task 1: Add Failing Integration Tests

**Files:**
- Modify: `test/integration/transactions_test.rb`

- [ ] **Step 1: Add view and destroy tests**

Add these tests after `lists only current user transactions` and before `creates an expense for current user`:

```ruby
test "lists transaction pictures with remove controls" do
  user = create(:user)
  transaction = create_transaction(user: user, comment: "Groceries")
  transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
  attachment = transaction.pictures.attachments.sole

  sign_in user
  get transactions_path

  assert_response :success
  assert_select "li", text: /receipt\.txt/i
  assert_select "form[action='#{transaction_picture_path(transaction, attachment)}'] button", text: /remove picture/i
end

test "removes one transaction picture for current user" do
  user = create(:user)
  transaction = create_transaction(user: user, comment: "Lunch")
  transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
  attachment = transaction.pictures.attachments.sole
  blob = attachment.blob
  sign_in user

  delete transaction_picture_path(transaction, attachment)

  assert_redirected_to transactions_path
  assert_not_predicate transaction.reload.pictures, :attached?
  refute_predicate transaction, :discarded?
  assert_not ActiveStorage::Blob.exists?(blob.id)
end

test "does not remove another user's transaction picture" do
  user = create(:user)
  other_user = create(:user)
  transaction = create_transaction(user: other_user, comment: "Other Lunch")
  transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
  attachment = transaction.pictures.attachments.sole
  sign_in user

  delete transaction_picture_path(transaction, attachment)

  assert_response :not_found
  assert_predicate transaction.reload.pictures, :attached?
end
```

- [ ] **Step 2: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_test.rb
```

Expected: FAIL because `transaction_picture_path` does not exist yet.

---

### Task 2: Add Route And Controller

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/transaction_pictures_controller.rb`

- [ ] **Step 1: Add nested HTML route**

Change the HTML transactions route from:

```ruby
resources :transactions, only: [ :index, :new, :create, :destroy ]
```

to:

```ruby
resources :transactions, only: [ :index, :new, :create, :destroy ] do
  resources :pictures, controller: "transaction_pictures", only: :destroy
end
```

- [ ] **Step 2: Add controller**

Create `app/controllers/transaction_pictures_controller.rb`:

```ruby
class TransactionPicturesController < ApplicationController
  before_action :authenticate_user!

  # DELETE /transactions/:transaction_id/pictures/:id
  def destroy
    transaction = policy_scope(Transaction).kept.find(params[:transaction_id])
    authorize transaction, :update?
    transaction.pictures.attachments.find(params[:id]).purge

    redirect_to transactions_path, notice: "Transaction picture removed."
  end
end
```

- [ ] **Step 3: Run tests**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_test.rb
```

Expected: view test still fails because the route works but the index does not render a remove button yet.

---

### Task 3: Add Remove Control To Index

**Files:**
- Modify: `app/views/transactions/index.html.erb`

- [ ] **Step 1: Replace picture filename spans with remove forms**

Inside the existing `transaction.pictures.each` loop, replace the standalone filename span with:

```erb
<div class="flex items-center gap-2 rounded-base bg-neutral-secondary-medium px-3 py-1 text-sm font-medium text-heading">
  <span><%= picture.filename %></span>
  <%= button_to "Remove picture",
    transaction_picture_path(transaction, picture.attachment),
    method: :delete,
    class: "text-danger hover:underline focus:outline-none" %>
</div>
```

- [ ] **Step 2: Verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_test.rb
```

Expected: PASS.

---

### Task 4: Verify And Commit

**Files:**
- All changed files from Tasks 1-3

- [ ] **Step 1: Run focused test**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_test.rb
```

Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run:

```bash
mise exec -- bin/rails test
```

Expected: PASS.

- [ ] **Step 3: Run RuboCop and ERB lint**

Run:

```bash
mise exec -- bin/rubocop app/controllers/transaction_pictures_controller.rb test/integration/transactions_test.rb config/routes.rb
mise exec -- bundle exec erb_lint app/views/transactions/index.html.erb
```

Expected: no offenses or lint errors.

- [ ] **Step 4: Commit**

Run:

```bash
git add config/routes.rb app/controllers/transaction_pictures_controller.rb app/views/transactions/index.html.erb test/integration/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction picture removal UI"
```

---

## Self-Review

- Spec coverage: Implements the Phase 6 attachment removal ownership behavior for the HTML UI.
- Scope control: Does not implement thumbnails, image previews, edit transaction forms, JS modals, API changes, or bulk removal.
- Placeholder scan: No placeholders remain.
