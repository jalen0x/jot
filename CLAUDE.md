# CLAUDE.md

Jalen Rails Template — Rails 8.1 starter with Devise, ViewComponent, and Solid Queue.

## Development Commands

```bash
bin/setup                    # Install dependencies and set up database
bin/dev                      # Start dev server (Overmind, auto-picks free port 3000-3099)
bin/rails test               # Minitest suite
bin/rails test:system        # Capybara + Selenium system tests
bin/rubocop                  # Omakase RuboCop
bin/rubocop -a               # Auto-fix
bin/brakeman --no-pager      # Security scanner
bin/bundler-audit check --update  # Gem CVE scan
bundle exec erb_lint --lint-all   # ERB linter
bin/ci                       # Run everything above locally
bin/rails db:prepare         # Set up database
bin/rails db:migrate         # Run migrations
```

### Custom Rake Tasks

```bash
rake setup:project    # Interactive — renders config/template_base.rb, config/database.yml, and config/deploy.yml
```

### Custom Generators

```bash
rails g template_base:override path/to/file  # Copy a template-base file into app/ for customization
```

## Architecture

- **Stack**: Rails 8.1, Ruby 4.0, PostgreSQL, Solid Queue / Solid Cache / Solid Cable, Propshaft, Hotwire (Turbo + Stimulus), TailwindCSS v4 + Flowbite 4, Devise, Pundit, ViewComponent + Lookbook
- **Template base**: Shared defaults can live in `lib/template_base/app/...`; app-level overrides in `app/...` win via `config.railties_order`
- **JS pipeline**: Hybrid — `importmap-rails` manages Stimulus/Turbo/app code; `bun run build` bundles Flowbite (via esbuild) into `app/assets/builds/flowbite.turbo.js`, which importmap pins. Don't assume "either importmap OR jsbundling" — both are intentional.
- **Authentication**: Devise with modular User concerns (`Users::Authenticatable`, `Users::Profile`, `Users::SoftDelete`). GitHub OmniAuth is the only OAuth provider.
- **Authorization**: Pundit (`ApplicationPolicy` included in `ApplicationController`).
- **Components**: ViewComponent under `app/components/`. Previews at `/lookbook` (development only) from `test/components/previews/`.
- **Deployment**: Kamal with project-specific `config/deploy.yml` + Cloudflare R2 for Active Storage in production.
- **Runtime config**: ENV-only for secrets/config, supplied through Kamal secrets or local env files when a loader such as `dotenv-rails` is configured. Do not read from Rails credentials.

### Four-Layer Model

All code in this app falls into one of four categories:

1. **Boundaries** — receive input, trigger logic, produce output. Controllers, Jobs, Mailers, Channels, Rake tasks. They are configuration, not OOP — keep them thin.
2. **Views** — ERB templates, JavaScript, CSS, Helpers, View Components. Server-side rendering is the default.
3. **Models** — Active Record (database) and Active Model (non-DB resources). Hold only configuration DSL, pure-DB class methods, and core domain instance methods. No business logic orchestration.
4. **Everything Else** — Services (`app/services/`), tests, config, dependencies. Business logic lives here, not in Active Record.

Rails gives you a complete architecture for free — don't build "a framework within the framework." The gap Rails doesn't fill is **where business logic goes**: it goes in the Service layer, not in "fat models."

### Design Philosophy

Inspired by *Sustainable Web Development with Ruby on Rails* (D. Copeland, 2025 edition):

- **Sustainability over cleverness** — changes tomorrow should be as easy as changes today, regardless of who makes them. No "we'll clean it up later" — that never happens.
- **Consistency** — solve the same problem the same way everywhere. Individual preference is not a valid input to architectural decisions. Consistency enables confident automation and migration (Stitch Fix: 3-person team migrated 100+ apps from Heroku to AWS because architecture was uniform).
- **Quality is non-negotiable** — when deadlines hit, cut scope, not quality. Only developers know which scope can be cut — this requires understanding the business context.
- **Minimize carrying cost** — every line of code, every dependency, every inconsistency is a cost you pay continuously. One-time investments that significantly reduce carrying cost are worth making (e.g., `bin/setup` over documentation, Service layer over fat models, design system over per-page CSS).
- **Measure before optimizing** — don't optimize without measurement. The bottleneck is often not where you think (real story: suspected slow app code, actual cause was warehouse Wi-Fi).
- **Monitor business outcomes, not just HTTP 5xx** — registration count dropping could be a marketing link pointing to staging, not a code bug. If you only monitor `SessionsController#create` returning 200, you'll never find it.
- **Automation > documentation** — `bin/setup`, `bin/dev`, `bin/ci` are the README. Scripts don't go stale; documents always do.
- **Callbacks for secondary concerns, Service layer for primary logic** — callbacks are good for simple, orthogonal side effects (notifications, audit, cache). Core business workflows belong in explicit Service classes where they're readable, testable, and don't inflate model fan-in (37signals, Jorge Manrubia: "plugging in a secondary function in a declarative way").

## Key Rules

### Soft Delete (discard gem)

`User` uses `include Discard::Model` via `Users::SoftDelete` — call `user.discard` / `user.undiscard`, not `destroy`. Default scope is `kept`. Purge attached files before discarding (e.g., `image.purge if image.attached?`). If you introduce new soft-deletable models, follow the same concern pattern; avoid adding `default_scope -> { kept }` to unrelated models.

### Solid Queue Background Jobs

- **Never use `discard_on`** to drop jobs. Let them fail so they're visible in the dashboard, retryable, and debuggable. Exceptions: `discard_on ActiveRecord::RecordNotFound` and `discard_on ActiveJob::DeserializationError` are allowed (the record is gone, retrying is pointless).
- Don't rescue exceptions without re-raising — failures must surface.
- Use `retry_on` for transient external failures.
- Rails 8.1+: use `wait: :polynomially_longer` (renamed from `:exponentially_longer`).
- Outside jobs, use `deliver_later` for mailers so request/command code does not block. Inside a job that owns the email side effect, `deliver_now` is acceptable because the queue is already the async boundary.
- Use `perform_now` only when the caller truly needs the result before proceeding.
- Pass primitive IDs/snapshot values to jobs by default. Passing models via GlobalID is allowed only when the lookup/retry semantics are intentional.

### Security

- **Authorization**: Queries must scope to the current user for user-owned resources — prefer `current_user.things.find(params[:id])` over `Thing.find(params[:id])`. Use Pundit policies for more complex access rules.
- Never expose internal error messages to end users — rescue early and return friendly messages.
- Never silently swallow exceptions — rescue specific errors and re-raise or report unknown errors.
- External API requests must be **outside** `ActiveRecord::Base.transaction` — slow/failed requests hold DB connections.
- External calls (HTTP, SSH, third-party SDK) must not run inline in controller actions — enqueue a Solid Queue job. See `.claude/rules/async-external-calls.md`.

### Database

- **Never add `default_scope`** — it causes hidden query side effects. The `Discard::Model`-provided `kept` scope in `Users::SoftDelete` is the narrow exception.
- Prefer `update!` over `update_columns` — don't skip `updated_at` and callbacks without a reason.
- Use `includes` / `preload` to avoid N+1 queries.
- Use `update_all` for batch operations, not per-record loops.
- Avoid reserved column names: `attributes`, `class`, `errors`, `hash`, `id`, `model_name`, `type` (STI). Prefix them (`llm_model`, `item_type`, `category_class`).

### Secrets & Config

Never hardcode secrets. Runtime config must be ENV-only (`ENV.fetch("NAME")`) and supplied through Kamal secrets or local env files when a loader such as `dotenv-rails` is configured. ENV values are strings; compare flags explicitly (`ENV["FEATURE"] == "true"`), never by truthiness.

Do not add or read `Rails.application.credentials`. Do not commit `config/master.key`, `config/credentials/*.key`, `config/credentials.yml.enc`, `config/credentials/*.yml.enc`, or raw secret values.

### Template Base Overrides

Default template files can ship from `lib/template_base/app/...`. When customizing one for an app, copy it into `app/...` first with `rails g template_base:override ...` instead of editing the shared base in place.

## UI Color Classes (Flowbite 4 Semantic)

Use Flowbite 4 semantic color classes. Never use hardcoded Tailwind colors (`gray-*`, `blue-*`, `primary-*`) or `dark:` color overrides — semantic variables handle dark mode automatically.

Full variable reference: `node_modules/flowbite/src/themes/default.css`

```erb
<%# Links %>
class="font-medium text-fg-brand hover:underline"

<%# Primary buttons %>
class="text-white bg-brand box-border border border-transparent hover:bg-brand-strong focus:ring-4 focus:ring-brand-medium shadow-xs font-medium leading-5 rounded-base text-sm px-4 py-2.5 focus:outline-none"

<%# Secondary buttons %>
class="text-body bg-neutral-secondary-medium box-border border border-default-medium hover:bg-neutral-tertiary-medium hover:text-heading focus:ring-4 focus:ring-neutral-tertiary shadow-xs font-medium leading-5 rounded-base text-sm px-4 py-2.5 focus:outline-none"

<%# Danger buttons (outline) %>
class="text-danger bg-neutral-primary border border-danger hover:bg-danger hover:text-white focus:ring-4 focus:ring-neutral-tertiary font-medium leading-5 rounded-base text-sm px-4 py-2.5 focus:outline-none"

<%# Form inputs %>
class="bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body"

<%# Cards/containers %>
class="bg-neutral-primary-soft border border-default rounded-base shadow-xs"

<%# File input (default) %>
class="cursor-pointer bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full shadow-xs placeholder:text-body"

<%# Checkbox (label right of checkbox) %>
<div class="flex items-center">
  <input type="checkbox" class="w-4 h-4 border border-default-medium rounded-xs bg-neutral-secondary-medium focus:ring-2 focus:ring-brand-soft">
  <label class="select-none ms-2 text-sm font-medium text-heading">Label</label>
</div>
```

Keep `text-white` on brand/danger backgrounds. Keep `after:bg-white` in toggle switches (slider stays white in both modes).

Prefer the existing `ButtonComponent` / `FormField::InputComponent` / `FormField::CheckboxComponent` / `FlashComponent` / `ModalComponent` over re-typing class strings. If you're copy-pasting the same classes twice, extend a component instead.

## Turbo Frame Modal Rules

Pages that serve as both a full page and a modal use a single `modal_content` Turbo Frame, toggled by `turbo_frame_request?`.

On the triggering link from a normal page, target the shared modal frame directly:

```erb
<%= link_to "Edit", edit_thing_path(thing), data: { turbo_frame: "modal_content" } %>
```

The target view must only wrap itself in `turbo_frame_tag "modal_content"` when `turbo_frame_request?` is true, so direct URL access still renders the full page.

For links/forms inside the modal that should stay in the modal, use the context-aware `modal_turbo_frame_data` helper:

```erb
<%= link_to "Sign up", new_registration_path(resource_name), data: modal_turbo_frame_data %>
```

It returns `{ turbo_frame: "modal_content" }` in a modal and `{}` on a full page. Do not hardcode `data: { turbo_frame: "modal_content" }` for in-modal links, because that breaks the standalone-page path.

## Compact Instructions

When compressing context, preserve in priority order:
1. Architecture decisions and constraints (NEVER summarize away)
2. Modified files and their key changes
3. Current verification status (pass/fail commands)
4. Open TODOs and rollback notes
5. Tool outputs can be deleted — keep pass/fail only

## Verification

| Task | Done condition |
|------|---------------|
| Model / controller change | `bin/rails test` passes |
| System test change | `bin/rails test:system` passes |
| View / CSS change | Visual check + `bin/rubocop` + `bundle exec erb_lint --lint-all` pass |
| Component change | Preview at `/lookbook` looks right + `bin/rails test` passes |
| Full pre-commit sweep | `bin/ci` passes |

## Agent skills

### Issue tracker

Issues and PRDs for this repo live in Linear and are managed with `linear-cli`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default five-label triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo: read root `CONTEXT.md` and root `docs/adr/` when present. See `docs/agents/domain.md`.

## Reference Documentation

Detailed guides are in `.claude/rules/` (auto-loaded by file path glob):

- `api.md` — API endpoint architecture, auth, and JSON conventions
- `architecture-design-docs.md` — design-doc rules for executable-code seams, LLM streaming, config, and capability state
- `architecture-evolution.md` — monolith/shared DB/microservices decision rules
- `async-external-calls.md` — Controller → Job → Turbo broadcast pattern for external I/O
- `authorization.md` — Devise, Pundit, role modeling, and access-control testing
- `ci-workflow.md` — bin/setup, bin/dev, bin/ci, and automation standards
- `configuration.md` — ENV-only runtime config and secrets
- `database.md` — DB schema, migration, and constraint rules
- `dependencies.md` — dependency addition, pinning, and update policy
- `generators.md` — generators, template_base, and generated-code standards
- `jobs.md` — Solid Queue job standards
- `mailers.md` — Mailer conventions, styling, and testing
- `observability.md` — logging, exception metadata, performance, and business metrics
- `r2-storage.md` — Cloudflare R2 Active Storage usage
- `rails-controllers.md` — Controller conventions
- `rails-models.md` — Model conventions
- `rails-views.md` — View conventions
- `rake-tasks.md` — Rake task organization and conventions
- `routes.md` — resource-oriented routing and custom URL rules
- `service-objects.md` — Service object conventions
- `stimulus-js.md` — Stimulus controller conventions
- `tailwind-v4.md` — Tailwind v4 rules, breaking changes, design guidelines
- `testing.md` — Minitest conventions
