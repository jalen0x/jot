# Transaction Resource Routes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace transaction collection custom API actions with Rails-native resource controllers and routes.

**Architecture:** Keep `Api::V1::TransactionsController` responsible for the transaction collection/member CRUD only. Move read projections and batch workflows into named resources that use canonical `index`, `show`, or `create` actions. Preserve the modern JSON shapes and snake_case params; do not keep legacy `.json` paths, old route aliases, camelCase params, or `success/result` envelopes.

**Tech Stack:** Rails 8.1 routes/controllers, Minitest integration tests, Pundit, existing ledger services.

---

### Task 1: Route Contract Tests

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Replace custom transaction route helpers with resource helpers**

Use these helper mappings in `test/integration/api/v1/transactions_test.rb`:

```ruby
count_api_v1_transactions_path                         -> api_v1_transaction_count_path
statistics_api_v1_transactions_path                    -> api_v1_transaction_statistics_path
trends_api_v1_transactions_path                        -> api_v1_transaction_trends_path
batch_delete_api_v1_transactions_path                  -> api_v1_transaction_deletions_path
batch_update_category_api_v1_transactions_path         -> api_v1_transaction_category_assignments_path
batch_update_account_api_v1_transactions_path          -> api_v1_transaction_account_assignments_path
move_between_accounts_api_v1_transactions_path         -> api_v1_transaction_account_moves_path
batch_add_tags_api_v1_transactions_path                -> api_v1_transaction_tag_assignments_path
batch_remove_tags_api_v1_transactions_path             -> api_v1_transaction_tag_removals_path
batch_clear_tags_api_v1_transactions_path              -> api_v1_transaction_tag_clearances_path
```

- [ ] **Step 2: Run focused test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb`

Expected: FAIL with missing route helper errors for the new resource helpers.

### Task 2: Resource Controllers and Routes

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`
- Modify: `app/policies/transaction_policy.rb`
- Create: `app/policies/transaction_count_policy.rb`
- Create: `app/policies/transaction_statistics_policy.rb`
- Create: `app/policies/transaction_trend_policy.rb`
- Create: `app/policies/transaction_deletion_policy.rb`
- Create: `app/policies/transaction_category_assignment_policy.rb`
- Create: `app/policies/transaction_account_assignment_policy.rb`
- Create: `app/policies/transaction_account_move_policy.rb`
- Create: `app/policies/transaction_tag_assignment_policy.rb`
- Create: `app/policies/transaction_tag_removal_policy.rb`
- Create: `app/policies/transaction_tag_clearance_policy.rb`
- Create: `app/controllers/api/v1/transaction_counts_controller.rb`
- Create: `app/controllers/api/v1/transaction_statistics_controller.rb`
- Create: `app/controllers/api/v1/transaction_trends_controller.rb`
- Create: `app/controllers/api/v1/transaction_deletions_controller.rb`
- Create: `app/controllers/api/v1/transaction_category_assignments_controller.rb`
- Create: `app/controllers/api/v1/transaction_account_assignments_controller.rb`
- Create: `app/controllers/api/v1/transaction_account_moves_controller.rb`
- Create: `app/controllers/api/v1/transaction_tag_assignments_controller.rb`
- Create: `app/controllers/api/v1/transaction_tag_removals_controller.rb`
- Create: `app/controllers/api/v1/transaction_tag_clearances_controller.rb`

- [ ] **Step 1: Add canonical resource routes**

Add top-level API resources before `resources :transactions`:

```ruby
resource :transaction_count, only: :show
resource :transaction_statistics, only: :show
resources :transaction_trends, only: :index
resources :transaction_deletions, only: :create
resources :transaction_category_assignments, only: :create
resources :transaction_account_assignments, only: :create
resources :transaction_account_moves, only: :create
resources :transaction_tag_assignments, only: :create
resources :transaction_tag_removals, only: :create
resources :transaction_tag_clearances, only: :create
```

Remove the custom collection actions from `resources :transactions`; keep transaction CRUD and nested pictures.

- [ ] **Step 2: Move action bodies into named controllers**

Move each custom action from `Api::V1::TransactionsController` into its named controller using canonical action names:

```ruby
count -> Api::V1::TransactionCountsController#show
statistics -> Api::V1::TransactionStatisticsController#show
trends -> Api::V1::TransactionTrendsController#index
batch_delete -> Api::V1::TransactionDeletionsController#create
batch_update_category -> Api::V1::TransactionCategoryAssignmentsController#create
batch_update_account -> Api::V1::TransactionAccountAssignmentsController#create
move_between_accounts -> Api::V1::TransactionAccountMovesController#create
batch_add_tags -> Api::V1::TransactionTagAssignmentsController#create
batch_remove_tags -> Api::V1::TransactionTagRemovalsController#create
batch_clear_tags -> Api::V1::TransactionTagClearancesController#create
```

Use the same existing services, params, errors, and response shapes. Authorize each new resource with its matching symbol policy, such as `authorize :transaction_count` for `show` and `authorize :transaction_deletion` for `create`. Keep user-owned record scoping exactly as before.

- [ ] **Step 3: Remove old custom policy predicates**

Remove the old custom action predicates from `TransactionPolicy` once no controller action uses them.

- [ ] **Step 4: Run focused test to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb`

Expected: PASS.

### Task 3: Verification and Commit

**Files:**
- All touched files from Tasks 1-2.

- [ ] **Step 1: Verify route table**

Run: `mise exec -- bin/rails routes -g transaction_`

Expected: resource routes exist for each new resource and old custom transaction collection action routes are absent.

- [ ] **Step 2: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run focused RuboCop**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/transactions_controller.rb app/controllers/api/v1/transaction_counts_controller.rb app/controllers/api/v1/transaction_statistics_controller.rb app/controllers/api/v1/transaction_trends_controller.rb app/controllers/api/v1/transaction_deletions_controller.rb app/controllers/api/v1/transaction_category_assignments_controller.rb app/controllers/api/v1/transaction_account_assignments_controller.rb app/controllers/api/v1/transaction_account_moves_controller.rb app/controllers/api/v1/transaction_tag_assignments_controller.rb app/controllers/api/v1/transaction_tag_removals_controller.rb app/controllers/api/v1/transaction_tag_clearances_controller.rb app/policies/transaction_policy.rb app/policies/transaction_count_policy.rb app/policies/transaction_statistics_policy.rb app/policies/transaction_trend_policy.rb app/policies/transaction_deletion_policy.rb app/policies/transaction_category_assignment_policy.rb app/policies/transaction_account_assignment_policy.rb app/policies/transaction_account_move_policy.rb app/policies/transaction_tag_assignment_policy.rb app/policies/transaction_tag_removal_policy.rb app/policies/transaction_tag_clearance_policy.rb config/routes.rb test/integration/api/v1/transactions_test.rb`

Expected: PASS with no offenses.

- [ ] **Step 4: Commit**

Run:

```bash
git add config/routes.rb app/controllers/api/v1 app/policies test/integration/api/v1/transactions_test.rb docs/superpowers/plans/2026-05-04-transaction-resource-routes-slice.md
git commit --no-gpg-sign -m "refactor: split transaction api custom actions into resources"
```
