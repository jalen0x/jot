# ezBookkeeping Transaction Templates HTML UI Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Rails SSR pages for listing, creating, and soft-deleting transaction templates.

**Architecture:** Follow existing ledger HTML patterns: authenticated controller, Pundit authorization, owner-scoped `policy_scope`, Flowbite semantic classes, and existing `TransactionTemplateCreator` for create behavior. This slice keeps UI simple and does not add edit/update forms; API already owns update/delete machine access.

**Tech Stack:** Rails 8.1, ERB, Pundit, Discard, Minitest integration tests, Flowbite semantic utility classes.

---

## File Structure

- Create `test/integration/transaction_templates_test.rb`: auth, owner-scoped list, create, delete, and cross-user delete tests.
- Modify `config/routes.rb`: add HTML `resources :transaction_templates, only: [:index, :new, :create, :destroy]`.
- Create `app/controllers/transaction_templates_controller.rb`: index/new/create/destroy.
- Create `app/views/transaction_templates/index.html.erb`: list templates and delete button.
- Create `app/views/transaction_templates/new.html.erb`: new template page.
- Create `app/views/transaction_templates/_form.html.erb`: create form for normal/scheduled template fields.

---

### Task 1: Add failing integration tests

**Files:**
- Create: `test/integration/transaction_templates_test.rb`

- [ ] **Step 1: Write failing tests**

Add tests covering:

1. Unauthenticated users are redirected from `transaction_templates_path`.
2. Index lists only the signed-in user's kept templates.
3. Create builds a scheduled template with owned account/category/tag and redirects to index.
4. Delete soft-deletes the signed-in user's template.
5. Deleting another user's template returns not found and does not discard it.

Use production-like string form params.

- [ ] **Step 2: Run tests RED**

Run: `mise exec -- bin/rails test test/integration/transaction_templates_test.rb`

Expected: FAIL because routes/controller/views are missing.

---

### Task 2: Add route and controller

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/transaction_templates_controller.rb`

- [ ] **Step 1: Add route**

Add near ledger resources:

```ruby
resources :transaction_templates, only: [ :index, :new, :create, :destroy ]
```

- [ ] **Step 2: Add controller**

Create `TransactionTemplatesController` with:

- `before_action :authenticate_user!`
- `index`: authorize class and load owner-scoped kept templates ordered by kind/order/name.
- `new`: build default template and load form collections.
- `create`: use `TransactionTemplateCreator`, redirect on success, render `new` with 422 on failure.
- `destroy`: owner-scoped lookup, `discard!`, redirect to index.

---

### Task 3: Add views

**Files:**
- Create: `app/views/transaction_templates/index.html.erb`
- Create: `app/views/transaction_templates/new.html.erb`
- Create: `app/views/transaction_templates/_form.html.erb`

- [ ] **Step 1: Add index view**

Use the existing card/list style from transactions/categories. Show name, template kind, transaction kind, account, category, amount, schedule frequency/rule, and tags. Include a `button_to "Delete"` for each template.

- [ ] **Step 2: Add new page and form**

Use existing semantic field classes. Include fields for:

- name
- template_kind
- transaction_kind
- account_id
- destination_account_id
- transaction_category_id
- source_amount_cents
- destination_amount_cents
- hide_amount
- transaction_tag_ids
- schedule_frequency
- schedule_rule
- schedule_start_on
- schedule_end_on
- scheduled_at_minutes
- timezone_utc_offset_minutes
- comment

- [ ] **Step 3: Run UI tests GREEN**

Run: `mise exec -- bin/rails test test/integration/transaction_templates_test.rb`

Expected: PASS.

---

### Task 4: Verify and commit the slice

**Files:**
- All files changed above.

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/integration/transaction_templates_test.rb test/integration/api/v1/transaction_templates_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run RuboCop for touched Ruby files**

Run: `mise exec -- bin/rubocop app/controllers/transaction_templates_controller.rb test/integration/transaction_templates_test.rb config/routes.rb`

Expected: PASS.

- [ ] **Step 4: Run ERB lint for touched views**

Run: `bundle exec erb_lint app/views/transaction_templates/index.html.erb app/views/transaction_templates/new.html.erb app/views/transaction_templates/_form.html.erb`

Expected: PASS.

- [ ] **Step 5: Commit implementation**

Run:

```bash
git add app/controllers/transaction_templates_controller.rb app/views/transaction_templates/index.html.erb app/views/transaction_templates/new.html.erb app/views/transaction_templates/_form.html.erb test/integration/transaction_templates_test.rb config/routes.rb
git commit --no-gpg-sign -m "feat: add transaction templates html ui"
```

Expected: commit succeeds and working tree is clean.

---

## Self-Review

- Spec coverage: adds Rails-native SSR access to Phase 7 transaction templates.
- Scope control: no edit UI, batch actions, JavaScript schedule wizard, or legacy API compatibility.
- Placeholder scan: no TODO/TBD placeholders remain.
- Testing fit: integration tests cover authentication, owner scoping, create, soft delete, and cross-user delete protection.
