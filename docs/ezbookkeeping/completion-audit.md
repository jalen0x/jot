# ezBookkeeping Rails Rewrite Completion Audit

Last updated: 2026-05-06
Audited scope: current Rails rewrite state through the Brakeman ledger filter slice.

## Objective Restated

Rewrite `/Users/Jalen/code/ezbookkeeping` as a Rails-native application in `/Users/Jalen/code/jot.jalenx.me`, following `AGENTS.md`, `CLAUDE.md`, and `.claude/rules/*`.

Concrete success criteria:

1. Preserve the selected ezBookkeeping domain capabilities in Rails-native resources, not legacy Go/Vue compatibility routes.
2. Keep explicit scope decisions: no legacy `.json`/camelCase/envelope compatibility, no MCP, no old frontend cloud-sync settings, no source-style OIDC provider matrix without concrete requirements.
3. Cover user-owned ledger workflows with Rails UI and Rails-native JSON API resources.
4. Keep business orchestration in service objects; controllers/jobs stay thin and authorized.
5. Use ENV-only runtime config and Rails-native infrastructure patterns.
6. Verify with relevant tests/lints and do not treat green tests as completion unless each requirement has direct evidence.

## Evidence Inspected

- `mise exec -- bin/rails ezbookkeeping:source_inventory`
  - Source inventory still reports 16 source models and 107 source API endpoints for traceability.
- `mise exec -- bin/rails routes | rg 'api/v1|two_factor|application_lock|api_tokens|sessions|external_auth|data_export|import_batch|ledger_clearance|transaction_template|scheduled|receipt|service_worker|manifest|pwa|map|transaction_picture'`
  - Rails routes include Rails-native API, Devise sessions, PWA routes, API tokens, 2FA, application lock, data export/import, ledger clearance, transaction templates, receipts, pictures, and transaction/statistics endpoints.
- `rg --files app test config db docs | rg 'two_factor|application_lock|api_token|session|external_auth|data_export|import_batch|import_file_parser|transaction_importer|ledger_clearance|transaction_template|scheduled|receipt|manifest|service_worker|pwa|picture|exchange_rate|user_preference|insight|map|geo|statistics|trends|reconciliation'`
  - Rails artifacts exist for most named parity areas.
- `docs/ezbookkeeping/behavior-coverage-audit.md`
  - Maps each selected parity capability to direct UI/API/system/service/job behavior tests and keeps explicit non-goals out of coverage.
- Latest verification for audited scope:
  - `mise exec -- bin/ci` on 2026-05-06 ran setup, setup idempotency, RuboCop, ERB lint, bundler-audit, importmap audit, Brakeman, Zeitwerk, Rails tests, and system tests successfully.
  - `mise exec -- bin/ci` then failed only at `gh signoff` because local `main` is ahead of `origin/main`; no code/test/security gate failed.
  - `mise exec -- bin/rails test` within CI -> 627 runs, 3516 assertions, 0 failures, 0 errors.
  - `mise exec -- bin/rails test:system` within CI -> 4 runs, 14 assertions, 0 failures, 0 errors.
  - `mise exec -- bin/rubocop` within CI -> 397 files inspected, no offenses detected.
  - `mise exec -- bundle exec erb_lint --lint-all` within CI -> 68 files linted, no errors.
  - `mise exec -- bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` within CI -> 0 security warnings.
- Representative desktop/mobile visual audit:
  - `mise exec -- bin/rails test tmp/visual_audit_test.rb` -> 1 run, 66 assertions, 0 failures, 0 errors.
  - The one-off visual audit loaded 16 representative signed-in Rails UI flows at 1440x1100 and 390x900, plus the mobile navigation menu.
  - Each captured page asserted no horizontal overflow via `document.documentElement.scrollWidth - document.documentElement.clientWidth`.
  - Contact sheets generated at `tmp/visual-audit/desktop-contact-sheet.png` and `tmp/visual-audit/mobile-contact-sheet.png` were manually inspected; no blocking layout issues were observed in the representative top-level flows.

## Prompt-to-Artifact Checklist

| Requirement | Evidence | Status | Notes / gaps |
| --- | --- | --- | --- |
| Source inventory and traceability | `Ezbookkeeping::SourceInventory`, `docs/ezbookkeeping/parity-map.md`, `docs/ezbookkeeping/data-migration-map.md`, source inventory command output, `docs/ezbookkeeping/behavior-coverage-audit.md` | Covered | Inventory is a traceability aid, not completion proof. |
| Scope: full Rails rewrite, no legacy API/frontend compatibility | `docs/ezbookkeeping/parity-map.md` scope decisions; routes are Rails-native `/api/v1/*` and standard Rails resources | Covered | No legacy `.json`, camelCase, `success/result`, or `legacy_json_path` requirements remain. |
| Scope: no MCP | `docs/ezbookkeeping/parity-map.md`; no Rails MCP controllers/routes | Covered | Machine access goes through Rails-native API and `jotctl`. |
| Scope: exclude old app cloud-sync settings | `docs/ezbookkeeping/parity-map.md`, `docs/ezbookkeeping/data-migration-map.md` | Covered | Source `UserApplicationCloudSetting` is explicitly excluded. |
| Accounts | `Account`, account controllers/API, account tests | Covered | Rails resource-oriented endpoints replace source account `.json` actions. |
| Opening balances | `Transaction` `balance_adjustment`, `TransactionRecorder`, tests | Covered | Uses Rails transaction records rather than source compatibility routes. |
| Categories, tag groups, tags | `TransactionCategory`, `TransactionTagGroup`, `TransactionTag`, controllers/API/tests | Covered | Ordering and lifecycle endpoints are Rails-native resources. |
| Transactions CRUD and filtering | `TransactionsController`, `Api::V1::TransactionsController`, `LedgerQuery`, integration/API tests | Covered | Includes batch assignments/deletions via explicit resources. |
| Dashboard and reports | `DashboardController`, `LedgerStatistics`, `LedgerTrends`, `TransactionAmountSummary`, `AccountBalanceTrends`, tests | Covered | JSON rendering moved onto result/resource objects where audited. |
| Account reconciliation | `AccountReconciliation`, UI/API controllers/tests | Covered | API returns resource JSON. |
| Insights explorers | `InsightExplorer`, UI/API controllers/tests | Covered | Source feature mapped to Rails resource. |
| Data export | `DataExport`, UI/API controllers/tests | Covered | CSV/TSV/JSON export exists. |
| Data import architecture | `ImportBatch`, `ImportFileParser`, `ImportBatchParserJob`, `TransactionImporter`, parser/importer/job tests, Phase 3 first-cut scope note | Covered for first cutover | Current first-cut imports CSV/TSV/JSON. Source third-party converters are explicitly deferred until real files/fixtures are required. |
| Data management statistics and clearing | `DataStatistics`, `LedgerClearance`, UI/API tests | Covered | Destructive operations use explicit resources. |
| User display/settings | `UserPreference`, UI/API controllers/tests | Covered | Includes locale/date/time/number/currency/coordinate/default-account/edit-scope settings. |
| Custom exchange rates | `UserCustomExchangeRate`, saver service, UI/API tests | Covered | User custom rates exist. |
| Automatic exchange rates | `ExchangeRateSnapshot`, `ExchangeRateRefreshJob`, `ExchangeRateProviders::BankOfCanada`, tests, Phase 4 first-cut scope note | Covered for first cutover | Bank of Canada plus user custom rates are the documented first deployment scope; additional source providers are deferred until required. |
| API tokens / source TokenRecord | `ApiToken`, `ApiTokenIssuer`, UI/API controllers/tests | Covered for API tokens | MCP token semantics intentionally not migrated. User-visible session management is not a separate persisted-session resource. |
| 2FA | `TwoFactorAuthentication`, recovery codes, UI/API/challenge tests | Covered | Recovery regeneration and challenge flows exist. |
| GitHub external auth | Devise GitHub OmniAuth plus `ExternalAuthentication`, UI/API tests | Covered | Other source providers are deferred by scope decision. |
| Application lock | `ApplicationLock`, session controllers/API/tests | Covered | Rails-native resource. |
| Transaction pictures | Active Storage attachments, `TransactionPicture` PORO, UI/API controllers/tests | Covered | R2 config remains ENV-based. |
| Geo locations and maps | transaction coordinate columns/validations, coordinate formatting, OpenStreetMap links/tests | Covered for first-cut Rails UI | Server-side tile/proxy adapters are deferred until concrete provider requirements exist. |
| PWA | `/manifest`, `/service-worker`, `app/views/pwa/*`, `test/integration/pwa_test.rb` | Covered | Rails views/assets, no Vue build. |
| Responsive Rails UI | Rails views and Flowbite/Tailwind conventions, integration tests, ERB lint, `test/system/navigation_test.rb` mobile-width overflow check, one-off representative desktop/mobile visual audit | Covered for representative cutover audit | Visual audit covered 16 signed-in top-level flows and the mobile menu with no horizontal overflow. This is not a pixel-perfect design signoff for every modal/subpage. |
| Transaction templates and schedules | `TransactionTemplate`, `ScheduledTransactionCreator`, `ScheduledTransactionCreationJob`, UI/API/job/service tests | Covered | Uses template kind and schedule fields instead of source routes. |
| Rails-native JSON API | `Api::V1::*` controllers, API integration tests, shared ledger filter param construction | Broadly covered | Route count is not a proxy for contract completeness; continue checking resource JSON as slices change. Ledger filter params are now plain hashes instead of `params.permit` pass-throughs. |
| LLM receipt recognition | `ReceiptRecognition`, job/client/processor, UI/API tests | Covered | External call is job-owned. |
| `.claude/rules` architecture | Thin controllers, Pundit policies, service layer, jobs, ENV config patterns across inspected files, behavior coverage audit | Broadly covered | Continue slice-by-slice enforcement; audit did not prove every file exhaustively. |
| Verification gates | Latest `bin/ci` code/test/security gates pass; `gh signoff` fails because `main` is unpushed | Covered as current health signal, except external signoff | Green tests do not prove unresolved product-scope decisions. Full `bin/ci` cannot finish locally until signoff can run against pushed commits or signoff is intentionally skipped. |

## Current Completion Decision

Do not mark the rewrite complete yet.

Missing or weakly verified items:

1. Full `bin/ci` still cannot finish the final `gh signoff` step while local `main` is ahead of `origin/main`; all code, test, style, and security gates passed before that external signoff step.

## Recommended Next Action

Continue with user-facing verification before declaring cutover readiness:

1. Resolve the external `gh signoff` blocker only when commits are ready to push or signoff is intentionally handled outside local CI.
