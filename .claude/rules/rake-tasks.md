---
paths:
  - "lib/tasks/**/*.rake"
  - "bin/*"
---

# Rake Task Standards

## Organization Rules

- **One task per file** — filename = task name (`change_approved_widgets_to_legacy.rake`).
- **Directory structure matches namespace** — `lib/tasks/db/updates/prod/countries.rake` → `db:updates:prod:countries`.
- **Always write `desc`** — tasks without `desc` don't show up in `bin/rails -T`, making them invisible.
- **Task names must be specific** — `change_approved_widgets_to_legacy`, not `legacy` or `update`.

## When to Use a Rake Task

Use a Rake task when automation needs the Rails app context: models, services, `Rails.root`, app configuration, or database access. Use `task name: :environment` for these tasks.

Good fits:

- recurring or manually triggered operational automation;
- production-data corrections that need an auditable trail in version control;
- runbook steps that would otherwise tell someone to paste Ruby or SQL into production.

If the automation does not need Rails internals, use a `bin/` script instead.

## Task Body Is One Line

The task body does one thing: call the Service layer. Business logic does not go in `.rake` files.

```ruby
desc "Changes all Approved widgets to Legacy that need it"
task change_approved_widgets_to_legacy: :environment do
  LegacyWidgets.new.change_approved_widgets_to_legacy
end
```

Do not put loops, SQL updates, branching business rules, or multi-step workflows in the `.rake` file. Put them in a normal Ruby class and test that class.

## One-off Tasks

Use a `one_off` namespace, backed by service classes in `app/services/one_off/`:

```ruby
# lib/tasks/one_off/fix_widget_pricing.rake
namespace :one_off do
  desc "Fixes widgets created before the 0.95 validation"
  task fix_widget_pricing: :environment do
    OneOff::WidgetPricing.new.change_to_95_cents
  end
end
```

One-off does not mean unstructured. The task still delegates to a class so the implementation is reviewable, testable, and easy to audit.

## Testing Rake Tasks

Do not write tests that only duplicate a one-line Rake task body. Test the service class that the task invokes. For the task itself, run it locally or run `bin/rails -T <namespace>` to confirm it loads and is discoverable.

## Rake Task vs `bin/` Script

| Feature | Rake Task | `bin/` script |
|---|---|---|
| Needs Rails environment | Good fit | Avoid unless necessary |
| Tab completion | Not supported | Supported |
| Argument passing | Unusual syntax | Standard CLI arguments |
| Help docs | `desc` string | OptionParser auto-generates |

**Conclusion**: developer automation that doesn't need Rails goes in `bin/` (Ruby or bash). Automation that needs Rails goes in `lib/tasks/`.

## Automation > Documentation

Rake tasks replace Markdown documents for operational procedures — humans make mistakes, automation doesn't. If you find the README saying "run these 5 steps…", that should be a Rake task.
