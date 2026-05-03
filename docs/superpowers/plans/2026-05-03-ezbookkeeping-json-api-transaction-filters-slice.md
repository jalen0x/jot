# ezBookkeeping JSON API Transaction Filters Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `GET /api/v1/transactions` filter by prefixed account, transaction category, and transaction tag IDs.

**Architecture:** Keep filtering inside `LedgerQuery`, which already owns transaction list filtering for Rails UI and API. Extend ID coercion there so numeric IDs from HTML forms and prefixed IDs from JSON API clients both work. The API controller only permits the additional query params and stays thin.

**Tech Stack:** Rails 8.1, existing `LedgerQuery`, prefixed_ids, Minitest service and API integration tests.

---

## File Structure

- Modify `test/services/ledger_query_test.rb`: prove prefixed tag/account/category filter IDs work.
- Modify `test/integration/api/v1/transactions_test.rb`: prove API list accepts prefixed account/category/tag query params and remains current-user scoped.
- Modify `app/services/ledger_query.rb`: decode prefixed IDs before applying ID filters.
- Modify `app/controllers/api/v1/transactions_controller.rb`: permit `account_id`, `transaction_category_id`, and `tag_id` query params.

---

### Task 1: Add prefixed ID filtering to `LedgerQuery`

**Files:**
- Modify: `test/services/ledger_query_test.rb`
- Modify: `app/services/ledger_query.rb`

- [ ] **Step 1: Write failing service tests**

Add tests proving `LedgerQuery#list_transactions` accepts prefixed IDs for `account_id`, `transaction_category_id`, and `tag_id`. Use decoy records so a raw unfiltered query would return more than one transaction.

Example assertion shape:

```ruby
transactions = LedgerQuery.new.list_transactions(user: user, filters: { account_id: matching.account.to_param })
assert_equal [ matching ], transactions.to_a
```

- [ ] **Step 2: Run service tests RED**

Run: `mise exec -- bin/rails test test/services/ledger_query_test.rb`

Expected: FAIL because prefixed IDs are not decoded before SQL filters.

- [ ] **Step 3: Implement prefixed ID coercion in `LedgerQuery`**

Update `app/services/ledger_query.rb` so ID filters pass through a small private helper:

```ruby
scope = scope.where(account_id: decoded_id(Account, filters[:account_id])) if filters[:account_id].present?
scope = scope.where(transaction_category_id: decoded_id(TransactionCategory, filters[:transaction_category_id])) if filters[:transaction_category_id].present?
scope = scope.joins(:transaction_taggings).where(transaction_taggings: { transaction_tag_id: decoded_id(TransactionTag, filters[:tag_id]) }) if filters[:tag_id].present?
```

Add:

```ruby
def decoded_id(model, value)
  model.decode_prefix_id(value) || value
end
```

- [ ] **Step 4: Run service tests GREEN**

Run: `mise exec -- bin/rails test test/services/ledger_query_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit service filtering**

```bash
git add app/services/ledger_query.rb test/services/ledger_query_test.rb
git commit --no-gpg-sign -m "feat: support prefixed ledger query filters"
```

---

### Task 2: Expose account/category/tag filters in the JSON API

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`

- [ ] **Step 1: Write failing API filter tests**

Add tests proving `GET /api/v1/transactions` accepts prefixed `account_id`, `transaction_category_id`, and `tag_id` query params. The tests should use the token owner's resources and decoy transactions that would appear if filtering failed. Also create another user's matching-looking transaction to prove current-user scoping still controls the result.

Use requests such as:

```ruby
get api_v1_transactions_path,
  params: { account_id: account.to_param },
  headers: json_headers(raw_token)
```

Assert the response is success and the returned IDs match only the expected transaction.

- [ ] **Step 2: Run API transaction tests RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb`

Expected: FAIL because `filter_params` only permits `transaction_kind`.

- [ ] **Step 3: Permit API filter params**

Update `filter_params` in `app/controllers/api/v1/transactions_controller.rb`:

```ruby
def filter_params
  params.permit(:transaction_kind, :account_id, :transaction_category_id, :tag_id)
end
```

- [ ] **Step 4: Run API transaction tests GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit API filter params**

```bash
git add app/controllers/api/v1/transactions_controller.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction api filters"
```

---

### Task 3: Verify JSON API transaction filters slice

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/services/ledger_query_test.rb test/integration/api/v1/transactions_test.rb test/integration/transactions_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/services/ledger_query.rb app/controllers/api/v1/transactions_controller.rb test/services/ledger_query_test.rb test/integration/api/v1/transactions_test.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: extends existing Phase 1 transaction filters into the Phase 8 JSON API seam with prefixed public IDs while keeping filtering centralized in `LedgerQuery`.
- Scope control: does not add date/amount/keyword filters, pagination, sorting options, legacy `.json` paths, update endpoints, or batch mutation.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: filter param names match existing Rails UI filters and API JSON field names.
