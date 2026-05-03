# ezBookkeeping JSON API Transaction Delete Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a token-authenticated JSON endpoint to delete a transaction and reverse its account balance effects.

**Architecture:** Extend the existing `Api::V1::TransactionsController` with `destroy`, scoped through `policy_scope(Transaction).kept` and authorized through Pundit. Deletion delegates to `TransactionReversal` so API behavior matches the existing Rails UI transaction deletion rules. Successful deletion returns `204 No Content`; business-rule failure returns explicit JSON errors.

**Tech Stack:** Rails 8.1, Pundit, ApiToken bearer auth, existing `TransactionReversal`, Minitest integration tests.

---

## File Structure

- Modify `config/routes.rb`: allow `destroy` for API transactions.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add `destroy` through `TransactionReversal`.
- Modify `test/integration/api/v1/transactions_test.rb`: API delete success and cross-user scoping failure.

---

### Task 1: Add `DELETE /api/v1/transactions/:id`

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing transaction delete API tests**

Add tests proving a bearer token can delete its own expense transaction, receives `204 No Content`, the transaction is discarded, and the account balance is reversed through `TransactionReversal`. Add a second test proving another user's transaction returns `404` and is not discarded.

Use the existing `issue_token`, `json_headers`, `create_account`, `create_category`, and `create_transaction` helpers. For the success case, create an account with `balance_cents: 3_750`, create an expense transaction with `source_amount_cents: 1_250`, then assert the balance becomes `5_000` after deletion.

- [ ] **Step 2: Run transaction API tests RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb`

Expected: FAIL because DELETE is not routed or controller action is missing.

- [ ] **Step 3: Implement transaction destroy**

Update `config/routes.rb`:

```ruby
resources :transactions, only: [ :index, :create, :destroy ]
```

Add `destroy` to `app/controllers/api/v1/transactions_controller.rb`:

```ruby
# DELETE /api/v1/transactions/:id
def destroy
  transaction = policy_scope(Transaction).kept.find(params[:id])
  authorize transaction
  result = TransactionReversal.new.delete_transaction(transaction: transaction)

  if result.deleted?
    head :no_content
  else
    render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
  end
end
```

- [ ] **Step 4: Run transaction API tests GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit transaction delete endpoint**

```bash
git add config/routes.rb app/controllers/api/v1/transactions_controller.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction delete api"
```

---

### Task 2: Verify JSON API transaction delete slice

- [ ] **Step 1: Run focused API and service tests**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb test/services/transaction_reversal_test.rb test/integration/api/authentication_test.rb test/integration/api/content_negotiation_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/transactions_controller.rb test/integration/api/v1/transactions_test.rb config/routes.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: extends the Phase 8 JSON API seam with delete access for transactions while preserving existing balance reversal rules and user scoping.
- Scope control: does not implement legacy ezBookkeeping `.json` paths, update endpoints, batch mutation, account/category/tag deletion, pagination, pictures, geo location, or MCP adapters.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: route helper, controller action, response status, and service call all use existing `Transaction` and `TransactionReversal` concepts.
