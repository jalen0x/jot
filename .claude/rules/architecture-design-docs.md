---
paths:
  - "docs/**/*.md"
---

# Architecture & Design Docs

Design docs are instructions future developers and agents will follow. Do not document patterns this project would reject in code.

## Same Rules as Code

- Runtime config in docs and examples is ENV-only. Do not mention Rails credentials as a runtime source or fallback; migration docs may mention them only as the thing being removed.
- Route examples follow `routes.md`: name resources first, use canonical actions, and do not show `member` / `collection` custom actions unless the doc explicitly records why a named resource would be worse.
- Service examples follow `service-objects.md`: business noun class, behavior-revealing verb method, no `Service` suffix, no generic `call`.
- Controller flows follow `async-external-calls.md`: external APIs do not run inline from request paths by default.
- Job examples follow `jobs.md`: known transient failures get explicit retry behavior; unknown failures surface.

## LLM and Streaming Flows

LLM calls are external I/O. Default to Controller -> Job -> persisted status/output -> Turbo/Action Cable broadcast.

If a product requirement truly needs request-path streaming, mark it as an explicit exception and document:

- timeout and cancellation behavior;
- retry or no-retry semantics;
- how partial output is persisted or discarded;
- user-visible failure behavior;
- monitoring/error reporting;
- rate limiting and concurrency limits;
- proof that no database transaction stays open during the stream.

Do not leave the design as "controller calls the LLM API and streams it" without those boundaries.

## No Executable Code Stored in Data

- Do not store Ruby, JavaScript, proc/lambda bodies, or executable response handlers in the database for later execution.
- Store a symbolic handler key and map it to approved adapter classes in code.
- If user-authored behavior is unavoidable, design a bounded DSL/JSON schema and document sandboxing, permissions, timeouts, audit logs, and allowed network/data access before implementation.

```ruby
# Good: data selects approved code
response_handler_key = "json_schema"
ResponseHandlers.fetch(response_handler_key).handle(response)

# Bad: data is code
eval(experiment.response_handler)
```

## Single Source of Truth

- For capability/configuration state, choose one owner and one query interface before adding columns or tables.
- Avoid storing the same fact in booleans and JSON/config rows unless the doc states precedence, sync rules, migration path, and one public reader.
- Name the reader the rest of the app should use, e.g. `CapabilityCatalog.enabled_for?(experiment, step, :ai)`.

## Design Review Checklist

Before implementing a non-trivial design doc, scan for these failure modes:

- runtime config has exactly one ENV-based source and no credentials fallback;
- routes are named resources with canonical actions; reports, statistics, trends, counts, searches, and batch workflows are not hidden as custom actions on broad controllers;
- controllers only translate HTTP and consume Result objects, not duplicate business decisions;
- service names and methods reveal behavior, without `Service` suffix or generic `call`;
- database design has one source of truth for workflow/capability state;
- JSONB is not hiding permissions, workflow state, or frequently queried domain fields;
- no executable code is stored in data;
- external provider calls are behind jobs/adapters unless an inline exception is documented;
- transactions contain database work only, with side effects after commit or through an outbox;
- CI uses the package manager selected by the lockfile.
