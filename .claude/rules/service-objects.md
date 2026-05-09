---
paths:
  - "app/services/**/*.rb"
---

# Service Object Standards

Services are the business-logic seam between Rails boundary objects and the domain. First principle: a call site should reveal behavior and read like a business sentence, not a framework invocation.

## Service Seam

A seam is the callable interface between Rails-managed boundary code and app-specific business behavior. For a service, the seam is the class name, public method name, accepted inputs, return value, and documented error behavior.

Example:

```ruby
summary = DashboardSummary.new.summarize(user: current_user)
```

The controller only needs to know `DashboardSummary#summarize(user:)` and the returned `Result` readers. It should not know the internal queries, transactions, callbacks, jobs, or private helper methods used to produce that result.

Use this test when reviewing a service seam:

- Can the call site be understood as a business sentence?
- Does the public method accept business-shaped data, not raw `params` or request objects?
- Does the return value expose only what callers need to decide what to render, redirect, enqueue, or report?
- If the implementation changes behind the seam, can the controller/job/rake task stay mostly unchanged?

## When to Create a Service

Create a service when the code is a named application use case that does more than Rails boundary plumbing or simple persistence.

Use a service when the behavior:

- coordinates multiple models, mailers, jobs, or external systems;
- contains business branching that a controller/job/rake task would otherwise own;
- needs a transaction around several writes;
- answers a business query whose rules are more than pure database shape (`fresh`, `eligible`, `billable`, `visible_to_user`);
- returns a business outcome the caller must react to.

Do **not** create a service for:

- one-line Active Record calls (`current_user.widgets.create(widget_params)` can stay inline);
- HTTP parameter coercion, authorization, rendering, redirects, flash, or Turbo responses — those stay in controllers;
- simple validations, associations, database constraints, or record-local behavior — those stay in models;
- a single-use helper that only makes another service shorter — make it a private method first;
- wrapping a job in a service just because it is asynchronous — Rails jobs already provide the async command boundary.

If the behavior cannot be named as a business sentence, do not extract it yet.

## What Belongs Inside

A service owns one use case from the domain point of view:

- deciding which business path applies;
- changing records that participate in that use case;
- building the Result object the caller needs;
- enqueueing follow-up jobs after durable state changes;
- calling private methods that make the workflow readable.

A service does **not** own request/response concerns. Controllers prepare trusted, typed inputs before calling the service; jobs pass IDs/snapshots intentionally; rake tasks parse CLI input and then call the service.

Split another service only when the sub-process has its own business name or multiple callers. Otherwise, private methods are cheaper and clearer.

## Transactions and Side Effects

Transactions protect database state, not the outside world. Keep transaction blocks small and free of side effects that cannot roll back.

- Inside a transaction: validate business preconditions, create/update/delete records, and use bang writes so failures roll back.
- Outside a transaction: enqueue jobs, send mail, broadcast, call external APIs, write files, and perform provider SDK operations.
- If a follow-up job depends on committed rows, enqueue it after the transaction block returns.
- If a side effect must happen exactly once with a database change, model an outbox/event row in the transaction and let a job process it after commit.
- Do not rescue inside the transaction just to return a failed Result; let unexpected failures roll back and surface.

```ruby
class WidgetPublisher
  def publish_widget(widget)
    publication = ActiveRecord::Base.transaction do
      widget.update!(published_at: Time.current)
      WidgetPublication.create!(widget:)
    end

    WidgetPublishedJob.perform_later(publication.id)
    nil
  end
end
```

## Naming

- **Classes are business nouns**: `WidgetCreator`, `LegacyWidgets`, `ClaudeMessageTokenCounter`, `ClaudeModelCatalog`.
- **No `Service` suffix** — it adds a layer label, not meaning. Drop it.
- **Methods are verbs**: `create_widget(params)`, `count_tokens(messages:)`, `change_to_95_cents`.
- **No generic `run` / `call` / `perform`** — they erase intent and block private-method decomposition.
- Sub-namespaces only for real grouping (`OneOff::`, `Admin::`).
- Architecture docs, diagrams, and examples must use the same names. Do not write `SchedulingService.call(...)` in a design doc and expect implementation to stay behavior-revealing.

```ruby
# Good — reads like a sentence
ClaudeMessageTokenCounter.new.count_tokens(messages:)
LegacyWidgets.new.change_approved_widgets_to_legacy

# Bad — framework noise
CountClaudeMessageTokensService.new.run
```

## Result vs Exceptions

Use a `Result` for expected business outcomes the caller must branch on.

Raise, or let exceptions raise, for unexpected failures, broken invariants, infrastructure problems, and programmer errors.

### Use Result for Expected Business Outcomes

Return a Result when the negative path is part of the use case, not a bug:

- user-correctable validation failure;
- business rule rejection (`not_eligible?`, `already_published?`, `insufficient_balance?`);
- idempotent no-op the caller should present differently (`already_invited?`);
- partial business outcome the caller needs to distinguish (`created?`, `updated_existing?`, `queued_for_review?`);
- a domain object with errors that the UI should render.

```ruby
result = WidgetCreator.new.create_widget(widget_params)

if result.created?
  redirect_to widget_path(result.widget)
else
  @widget = result.widget
  render :new, status: :unprocessable_content
end
```

Use non-bang persistence only when the failure is an expected business outcome you will put into the Result:

```ruby
class WidgetCreator
  def create_widget(params)
    widget = Widget.new(params)

    if widget.save
      Result.new(created: true, widget:)
    else
      Result.new(created: false, widget:)
    end
  end
end
```

### Raise for Unexpected Failures

Do not convert unknown failures into `Result.new(created: false)` or `Result.failed`. Let them surface.

Raise, or use bang methods, when failure means the code or environment is wrong:

- required internal record is missing;
- a database constraint, transaction, or lock fails;
- an external API/client raises;
- a job cannot complete and should be retried or shown as failed;
- code reaches an impossible state;
- a caller violates the service contract.

```ruby
class WidgetPublisher
  def publish_widget(widget)
    raise ArgumentError, "widget must be approved" unless widget.approved?

    ActiveRecord::Base.transaction do
      widget.update!(published_at: Time.current)
      WidgetPublication.create!(widget:)
    end

    nil
  end
end
```

Rule of thumb: if the user can fix it, return a Result; if a developer/operator must fix it, raise. Do not use exceptions for ordinary business branching, and do not use Result to hide exceptional failures.

## Return Values

When a method needs to return more than one thing, use a nested `Result` class.

```ruby
class WidgetCreator
  def create_widget(params)
    widget = Widget.create(params)
    Result.new(created: widget.valid?, widget: widget)
  end

  class Result
    attr_reader :widget
    def initialize(created:, widget:) = (@created, @widget = created, widget)
    def created? = @created
  end
end
```

- **Fields are business nouns**: `widget:`, `models:`, `token_count:` — not generic `payload:` / `data:` / `result:`.
- **Past-tense predicates**: `created?` / `charged?` / `published?` — not `success?` / `ok?`. Future UI needs (`created? && pending_review?`) then only touch the Result class.
- A Result may expose multiple business predicates when the caller needs them (`created?`, `existing_widget_updated?`, `queued_for_review?`).
- Include only fields callers actually need. Prefer returning an Active Model/Active Record with validation errors over copying errors into strings.
- Do not create a generic `ApplicationResult`, `Success`, `Failure`, or monadic result library by default. The Result is part of this service's seam.
- Pure side-effect methods return nothing.

## Don't Over-Decompose

- Don't wrap a single delegation in a service — inline it.
- Don't create single-use helper classes (`SomethingFinder` called once) — make it a private method.
- Don't inject dependencies just for testability. `allow(Widget).to receive(:create)` works directly. Constructor takes only what the caller must configure.

## Other

- Business data/context goes in the verb method (`create_widget(widget)`), not split between `initialize` and `call`. Constructors take only dependencies the caller must configure.
- External API calls (HTTP, SSH, third-party SDK) stay **outside** transactions and belong in a Solid Queue job — see `async-external-calls.md`.
- Never swallow exceptions silently.
