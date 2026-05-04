# ezBookkeeping Rails Parity Map

## Source Coverage Inputs

- README feature list: self-hosting, desktop/mobile UI, PWA, AI receipt recognition, MCP, two-level accounts/categories, pictures, locations, scheduled transactions, filtering, statistics, localization, multi-currency, exchange rates, 2FA, OIDC, app lock, import/export.
- Source models from `cmd/database.go`: User, TwoFactor, TwoFactorRecoveryCode, TokenRecord, Account, Transaction, TransactionCategory, TransactionTagGroup, TransactionTag, TransactionTagIndex, TransactionTemplate, TransactionPictureInfo, UserCustomExchangeRate, UserApplicationCloudSetting, UserExternalAuth, InsightsExplorer.
- Source API endpoint count from `cmd/webserver.go`: 107 total API endpoints, including 102 `apiV1Route` endpoints.
- Source frontend routes: desktop and mobile route files under `src/router`.

## Scope Decisions

- Rails is a complete rewrite, not a compatibility adapter for the Go/Vue app.
- Do not preserve legacy `.json` URLs, camelCase params, `success/result` envelopes, or old frontend contracts.
- Do not implement MCP. Machine access is through the Rails-native API and the separate `jotctl` CLI.

## Rails Phases

| Source capability | Rails phase | Rails artifact |
| --- | --- | --- |
| Source inventory and migration traceability | Phase 0 | `Ezbookkeeping::SourceInventory`, `docs/ezbookkeeping/*` |
| Accounts | Phase 1 | `Account`, `AccountCreator`, `AccountsController` |
| Opening balance transactions | Phase 1 | `Transaction` with `balance_adjustment` kind |
| Transaction categories | Phase 1 | `TransactionCategory` |
| Transaction tag groups and tags | Phase 1 | `TransactionTagGroup`, `TransactionTag`, `TransactionTagging` |
| Income, expense, transfers, balance adjustment | Phase 1 | `TransactionRecorder` |
| Transaction filters and list | Phase 1 | `LedgerQuery`, `TransactionsController` |
| Dashboard | Phase 1 | `DashboardController` |
| Transaction statistics and trends | Phase 2 | `LedgerStatistics`, `LedgerTrends` |
| Account reconciliation statement | Phase 2 | `AccountReconciliation` |
| Insights explorers | Phase 2 | `InsightExplorer` |
| Data export | Phase 3 | `DataExport` |
| Data import | Phase 3 | `ImportBatch`, parser jobs, `TransactionImporter` |
| Data clearing | Phase 3 | `LedgerClearance` |
| User display settings | Phase 4 | `UserPreference` or selected `User` columns |
| Custom exchange rates | Phase 4 | `UserCustomExchangeRate` |
| Automatic exchange rates | Phase 4 | `ExchangeRateSnapshot`, provider jobs |
| Sessions and API tokens | Phase 5 | Rails session/token resources |
| Two-factor authentication | Phase 5 | `TwoFactorAuthentication` resources |
| OIDC/external auth | Phase 5 | `ExternalAuthentication` resources |
| Application lock | Phase 5 | `ApplicationLock` resources |
| Transaction pictures | Phase 6 | Active Storage attachments |
| Geo locations and maps | Phase 6 | transaction location columns and map adapters |
| PWA and responsive mobile UI | Phase 6 | Rails views/assets |
| Transaction templates and schedules | Phase 7 | `TransactionTemplate`, recurring job |
| Rails-native JSON API | Phase 8 | `Api::V1` resource controllers with top-level JSON keys |
| LLM receipt recognition | Phase 8 | recognition job/result resources |
| MCP support | Excluded | Not part of the Rails rewrite scope |
