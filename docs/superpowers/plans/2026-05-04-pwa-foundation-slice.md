# PWA Foundation Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the Rails-native PWA manifest and service-worker foundation already present in the app.

**Architecture:** The app already has `app/views/pwa/manifest.json.erb` and `app/views/pwa/service-worker.js`. This slice wires the canonical Rails PWA routes, links the manifest from the application layout, and registers the service worker from `app/javascript/application.js`. It keeps app-level view overrides ahead of template-base views so `app/views/layouts/application.html.erb` wins over the shared layout. It does not add push notifications, offline caching strategy, custom icons, or mobile-specific routes.

**Tech Stack:** Rails 8.1 PWA route endpoints, Importmap JavaScript, Minitest integration tests, ERB lint.

---

## Files

- Modify: `config/routes.rb`
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/javascript/application.js`
- Modify: `lib/template_base/engine.rb`
- Create: `test/integration/pwa_test.rb`
- Create: `docs/superpowers/plans/2026-05-04-pwa-foundation-slice.md`

## Task 1: RED Tests

- [x] **Step 1: Add integration tests**

Create `test/integration/pwa_test.rb` covering manifest response JSON, service-worker response, and layout manifest link.

- [x] **Step 2: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/pwa_test.rb
```

Expected: route/helper errors because PWA routes are still commented out.

## Task 2: Implementation

- [x] **Step 1: Enable routes**

Uncomment/add `pwa_manifest` and `pwa_service_worker` routes in `config/routes.rb`.

- [x] **Step 2: Link manifest**

Add `<link rel="manifest" href="<%= pwa_manifest_path(format: :json) %>">` in the application layout head.

- [x] **Step 3: Register service worker**

Add a small browser capability check in `app/javascript/application.js` that registers `/service-worker.js` on window load.

- [x] **Step 4: Ensure app layout overrides template base**

Change the template-base view path from `prepend_view_path` to `append_view_path` so app-level layouts and views override shared defaults as documented.

- [x] **Step 5: Verify GREEN**

Run the focused PWA integration test.

## Task 3: Verification And Merge

- [x] **Step 1: Run full Rails tests**

```bash
mise exec -- bin/rails test
```

Expected: 0 failures, 0 errors.

- [x] **Step 2: Run targeted RuboCop and ERB lint**

```bash
mise exec -- bin/rubocop config/routes.rb test/integration/pwa_test.rb lib/template_base/engine.rb
mise exec -- bundle exec erb_lint app/views/layouts/application.html.erb
```

Expected: no offenses.

- [x] **Step 3: Commit implementation**

```bash
git add docs/superpowers/plans/2026-05-04-pwa-foundation-slice.md config/routes.rb app/views/layouts/application.html.erb app/javascript/application.js test/integration/pwa_test.rb lib/template_base/engine.rb
git commit --no-gpg-sign -m "feat: enable pwa foundation"
```

- [x] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/pwa-foundation-slice
mise exec -- bin/rails test
```

- [x] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/pwa-foundation-slice
git branch -d feature/pwa-foundation-slice
```
