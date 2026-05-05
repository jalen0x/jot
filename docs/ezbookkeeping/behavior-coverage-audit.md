# ezBookkeeping Behavior Coverage Audit

Last updated: 2026-05-06

Purpose: close the completion-audit risk that broad parity rows were judged by artifact existence instead of representative behavior.

## Method

- Used `docs/ezbookkeeping/parity-map.md` as the selected-scope source of truth.
- Inspected integration, API integration, system, service, and job test names for each selected capability.
- Counted route/model/file existence only as supporting evidence, never as behavior proof by itself.
- Kept explicit scope exclusions out of behavior coverage: legacy `.json`/camelCase/envelope compatibility, MCP, old frontend cloud-sync settings, and source-style OIDC/Gitea/Nextcloud provider matrix.

## Behavior Checklist

| Selected capability | Direct behavior evidence inspected | Coverage decision |
| --- | --- | --- |
| Authentication boundary | `test/integration/api/authentication_test.rb`, `test/integration/api/content_negotiation_test.rb`, Devise login/system tests | Covered |
| Accounts and account hierarchy | `test/integration/accounts_test.rb`, `test/integration/api/v1/accounts_test.rb`, `test/services/account_creator_test.rb` | Covered |
| Opening balances | `test/services/account_creator_test.rb`, `test/services/transaction_recorder_test.rb`, account create/update integration tests | Covered |
| Categories, tag groups, and tags | UI/API integration tests for transaction categories, tag groups, and tags | Covered |
| Transactions CRUD | `test/integration/transactions_test.rb`, `test/integration/api/v1/transactions_test.rb`, recorder/updater/reversal service tests | Covered |
| Transaction filters and aggregate filters | `test/integration/transactions_filters_test.rb`, API transaction filter/aggregate tests, `test/services/ledger_query_test.rb` | Covered |
| Batch transaction actions | API transaction batch tests for delete, category, account, add/remove/clear tags; service tests for each batch updater | Covered |
| Dashboard and reports | `test/integration/dashboard_test.rb`, `test/integration/reports_test.rb`, dashboard/statistics/trends/amount-summary service tests | Covered |
| Account reconciliation | `test/integration/account_reconciliation_statements_test.rb`, API account reconciliation tests, `test/services/account_reconciliation_test.rb` | Covered |
| Insights explorers | `test/integration/insight_explorers_test.rb`, `test/integration/api/v1/insight_explorers_test.rb`, model tests | Covered |
| Data export | UI/API data export integration tests and `test/services/data_export_test.rb` | Covered |
| Data import first cutover | UI/API import batch tests, parser job tests, import parser/importer/round-trip service tests | Covered for CSV/TSV/JSON first cutover |
| Data statistics and clearing | UI/API data management and ledger clearance tests, `test/services/data_statistics_test.rb`, `test/services/ledger_clearance_test.rb` | Covered |
| User profile/avatar/preferences | UI/API profile, avatar, and preference tests; preference model/helper tests | Covered |
| Custom exchange rates | UI/API custom exchange-rate tests and saver/model tests | Covered |
| Automatic exchange rates | exchange-rate catalog UI/API tests plus Bank of Canada provider/job tests | Covered for Bank of Canada first cutover |
| API tokens | UI/API token tests and issuer/model tests | Covered |
| Login rate limiting | `test/integration/login_rate_limits_test.rb` | Covered |
| Two-factor authentication | UI/API setup tests, challenge tests, recovery-code tests, model/service tests | Covered |
| GitHub external auth | external authentication UI/API tests and GitHub authenticator service tests | Covered for GitHub-only scope |
| Application lock | UI/API application-lock tests and application-lock model tests | Covered |
| Transaction pictures | transaction UI/API picture tests and Active Storage attachment assertions | Covered |
| Geo locations and maps | transaction UI/API location tests, coordinate preference tests, OpenStreetMap link assertions | Covered for first-cut Rails UI |
| PWA | `test/integration/pwa_test.rb` and manifest/service-worker views | Covered |
| Responsive Rails UI | `test/system/navigation_test.rb` and 2026-05-06 one-off desktop/mobile visual audit of 16 signed-in top-level flows | Covered for representative cutover audit |
| Transaction templates and schedules | UI/API transaction-template tests, scheduled transaction creator/job tests | Covered |
| Rails-native JSON API | API auth/content negotiation tests plus resource-specific API integration tests across selected capability rows | Covered |
| LLM receipt recognition | UI/API receipt-recognition tests, processor/client/job tests | Covered |
| Scope exclusions | `docs/ezbookkeeping/parity-map.md`, route/API conventions, absence of MCP/legacy compatibility requirements | Covered as explicit non-goals |

## Remaining Non-Behavior Blocker

`mise exec -- bin/ci` passed setup, style, security, Zeitwerk, Rails tests, and system tests on 2026-05-06, then failed only at `gh signoff` because local `main` is ahead of `origin/main`. That is an external signoff/push-state blocker, not a product behavior gap.
