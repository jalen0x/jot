# ezBookkeeping Rails Rewrite Design

## Objective

用 Rails 重写 `/Users/Jalen/code/ezbookkeeping`，目标是在当前 Rails 8.1 模板应用中逐步替换 Go + Vue 版本的自托管个人记账产品，并持续遵守 `AGENTS.md` 与 `.claude/rules/`。

这不是一次性大爆炸改写。源项目包含 447 个 Go 文件、351 个 Vue/TypeScript 文件、102 个 `/api/v1` JSON 端点，以及桌面和移动两套前端路由。Rails 重写必须先产出可验证的 Rails-native 产品核心，再按阶段扩展到全量功能。

## Source Evidence

本设计基于本地源项目证据，不依赖外部文档：

- 产品功能来自 `/Users/Jalen/code/ezbookkeeping/README.md`：自托管、轻量、桌面/移动 UI、PWA、暗色模式、AI 收据识别、MCP、两级账户和分类、交易图片、位置、周期交易、筛选/统计/分析、多语言、多币种、汇率、时区、2FA、OIDC、登录限制、应用锁、数据导入导出。
- Rails 目标仓库当前状态：`config/routes.rb` 只有 Devise、Lookbook、health check 和 `root "home#show"`；`db/structure.sql` 只有 Rails metadata 和 `users` 表；没有记账领域模型。
- 源项目持久化模型来自 `/Users/Jalen/code/ezbookkeeping/cmd/database.go` 的 `SyncStructs`：`User`、`TwoFactor`、`TwoFactorRecoveryCode`、`TokenRecord`、`Account`、`Transaction`、`TransactionCategory`、`TransactionTagGroup`、`TransactionTag`、`TransactionTagIndex`、`TransactionTemplate`、`TransactionPictureInfo`、`UserCustomExchangeRate`、`UserApplicationCloudSetting`、`UserExternalAuth`、`InsightsExplorer`。
- 源项目主要 API 来自 `/Users/Jalen/code/ezbookkeeping/cmd/webserver.go`：认证、tokens、用户资料、头像、外部认证、云设置、2FA、数据统计/清理/导出、账户、交易、交易图片、分类、标签组、标签、交易模板、insights explorers、LLM 收据识别、汇率、版本。
- 源项目 AI/CLI 能力边界来自 `/Users/Jalen/code/ezbookkeeping/skills/ezbookkeeping/scripts/ebktools.sh`：tokens、accounts、transaction categories、transaction tags、transactions、exchange rates、server version。

## Success Criteria

完整重写完成时必须满足这些条件：

1. Rails 应用可以独立运行、部署和维护，不再依赖 Go 服务或 Vue SPA 才能完成核心产品流程。
2. 用户可以完成 ezBookkeeping 的核心工作：注册/登录、创建账户、创建分类和标签、记录收入/支出/转账/余额调整、筛选交易、查看统计、导入导出数据、配置用户偏好和安全设置。
3. Rails 数据模型保护核心财务完整性：金额使用 integer cents；所有用户数据 scoped to user；核心外键、唯一性、枚举/状态约束由数据库兜底；无 `default_scope`。
4. 外部 I/O 不在 controller request path 内直接执行：汇率源、地图代理、OIDC、邮件、对象存储、LLM、MCP 和导入解析的慢任务通过 jobs/adapters 或明确例外实现。
5. Rails UI 使用 SSR + Hotwire 为默认交互模型，使用现有 ViewComponent 和 Flowbite semantic color classes；避免复制 Vue SPA 架构。
6. API 兼容仅在有实际客户端或迁移需要时作为适配层实现；Rails canonical routes 仍以 resource-oriented URL 为主。
7. 每个阶段有窄范围测试和验证门槛；不能用“已有大量实现”或“测试全绿”代替未覆盖需求的验收。

## Product Decomposition

### Phase 0: Parity Inventory And Migration Map

目标是建立可追踪清单，避免“感觉已经重写了”但遗漏源功能。

Deliverables:

- `docs/ezbookkeeping/parity-map.md`：把源项目 README 功能、Go models、Go API endpoints、桌面/移动路由映射到 Rails 阶段。
- `docs/ezbookkeeping/data-migration-map.md`：记录源模型字段到 Rails 表/字段的映射、不可迁移字段、转换规则。
- 源端点清单脚本或 rake task，只读扫描 `/Users/Jalen/code/ezbookkeeping/cmd/webserver.go`，输出端点数量和分组。

Verification:

- 清单覆盖 `cmd/database.go` 的所有 `SyncStructs` 模型。
- 清单覆盖 `cmd/webserver.go` 的所有注册 API endpoints。
- 清单覆盖 `src/router/desktop.ts` 和 `src/router/mobile.ts` 的用户可达页面。

### Phase 1: Core Ledger MVP

目标是 Rails-native 的最小可用记账产品，不做 API 兼容优先。

Entities:

- `Account`：用户拥有；两级自关联；类别、类型、币种、余额、颜色、图标、备注、排序、隐藏、软删除。
- `TransactionCategory`：用户拥有；两级自关联；收入/支出/转账类别；图标、颜色、备注、排序、隐藏、软删除。
- `TransactionTagGroup`：用户拥有；名称、排序、软删除。
- `TransactionTag`：用户拥有；可选分组、名称、排序、隐藏、软删除。
- `Transaction`：用户拥有；类型、时间、时区偏移、源账户、目标账户、分类、源金额、目标金额、隐藏金额、备注、地理坐标预留、软删除。
- `TransactionTagging`：交易和标签多对多。

Canonical Rails routes:

- `resources :accounts`
- `resources :transaction_categories`
- `resources :transaction_tag_groups`
- `resources :transaction_tags`
- `resources :transactions`
- `resource :dashboard, only: :show`

Service seams:

- `AccountCreator#create_account(user:, attributes:, sub_accounts:)` creates accounts and optional opening-balance transaction.
- `AccountUpdater#update_account(account:, attributes:, sub_accounts:)` updates account configuration without hiding balance rules in controllers.
- `TransactionRecorder#record_transaction(user:, attributes:, tag_ids:)` creates income, expense, transfer, and balance-adjustment transactions and updates account balances in one database transaction.
- `TransactionReversal#delete_transaction(transaction:)` soft-deletes a transaction and reverses account balances when business rules allow deletion.
- `LedgerQuery#list_transactions(user:, filters:)` owns filtering by date, type, category, account, tag, amount, and keyword.

Important rules:

- Account balance is derived by controlled writes through transaction services, not arbitrary controller updates.
- Balance adjustment transactions cannot be added after normal transactions already exist for that account, matching the source service rule.
- Transfer between same-currency accounts must use equal source/destination amounts.
- Transfers cannot use negative source or destination amounts.
- Hidden parent accounts/categories/tags are UI state, not authorization state.

Verification:

- Service tests for opening balance, income, expense, transfer, deletion reversal, and invalid transfer rules.
- Integration/system tests for user scoping: one user cannot see or mutate another user's ledger data.
- DB constraint tests for money, ownership, foreign keys, type values, and self-parent invariants.
- `bin/rails test` passes for touched slices.

### Phase 2: Statistics, Reports, And Reconciliation

目标是替代源项目交易统计、趋势、资产趋势、金额汇总和账户对账页面。

Entities and services:

- `LedgerStatistics#summarize_transactions(user:, range:, filters:)` returns income, expense, balance, category totals, and account totals.
- `LedgerTrends#build_transaction_trends(user:, range:, aggregation:, filters:)` returns chart-ready time buckets.
- `AccountReconciliation#build_statement(account:, range:)` returns opening balance, closing balance, inflows, outflows, and ordered transactions.
- Saved explorer configuration uses `InsightExplorer` with structured JSONB data for chart dimensions and filters only. It must not store executable Ruby/JavaScript or arbitrary response handlers.

Routes:

- `resource :reports, only: :show` or separate resources when UI concepts split cleanly.
- `resources :insight_explorers` for saved explorer configurations.
- Query params hold filtering/sorting/date state on index/show routes.

Verification:

- Service tests with decoy accounts/categories/tags so wrong scoping or ordering fails loudly.
- System tests for primary report pages only after services are covered.
- Performance checks before adding generated columns or specialized indexes.

### Phase 3: Import, Export, And Data Management

目标是覆盖源项目的数据导入导出和数据清理功能。

Import sources from source project:

- ezBookkeeping CSV/TSV/JSON
- Custom CSV/TSV/Excel
- Alipay, WeChat Pay, Feidee MyMoney, JD Finance
- OFX/QFX, QIF, IIF, CAMT.052/053, MT940
- GnuCash, Firefly III, Beancount

Architecture:

- `DataExport` creates CSV/TSV exports from Rails ledger data.
- `ImportFileParser` parses uploaded files in a Solid Queue job and persists a preview/import batch.
- `TransactionImporter#import_transactions(import_batch:)` validates and records selected transactions through `TransactionRecorder`.
- Import parsing never runs inline in controllers because large files and third-party formats are slow and failure-prone.
- Import batches store source file metadata and parsed rows as bounded JSONB snapshots. Core money, account, category, and transaction facts are promoted to relational tables during import.

Routes:

- `resource :data_management, only: :show`
- `resources :data_exports, only: [:create, :show]`
- `resources :import_batches, only: [:new, :create, :show, :update]`
- Separate deletion resources for destructive operations if UI needs explicit flows, e.g. `resource :ledger_clearance, only: [:new, :create]`.

Verification:

- Converter tests for each imported source with fixtures from `/Users/Jalen/code/ezbookkeeping/testdata` where applicable.
- Job tests for parse success/failure status.
- Service tests prove imported rows create the same ledger effects as manually recorded transactions.

### Phase 4: User Settings, Localization, Currency, And Exchange Rates

目标是覆盖语言、日期/数字/货币显示、默认账户/币种、应用云设置和汇率。

Entities:

- `UserPreference` or columns on `User`, chosen once as the source of truth for profile/display settings.
- `UserCustomExchangeRate` for per-user overrides.
- `ExchangeRateSnapshot` for provider data if automatic rates are enabled.
- `ApplicationCloudSetting` only if the Rails app keeps an equivalent of source “application cloud settings”。

Architecture:

- Runtime config is ENV-only; no Rails credentials.
- `ExchangeRateUpdater#refresh_rates(provider_key:)` runs in a job and calls provider adapters outside database transactions.
- `ExchangeRateCatalog#latest_rates(user:)` merges provider rates and user custom rates with documented precedence.
- Locale files under `config/locales/` hold UI strings; no user-facing strings buried in services.

Verification:

- Service tests for custom exchange-rate precedence.
- Job tests for provider success/transient failure retry behavior.
- View/system checks for representative locale and formatting flows.

### Phase 5: Security, Sessions, External Auth, And Application Lock

目标是替代源项目 tokens、2FA、OIDC 外部认证、应用锁、会话列表和登录限制。

Rails choices:

- Keep Devise as primary authentication.
- Use existing GitHub OmniAuth only until additional OIDC providers are explicitly required.
- Add 2FA via a Rails-native implementation when phase starts; do not preserve Go token internals.
- Session/token management uses Rails/Devise concepts first. API tokens and MCP tokens become explicit `ApiToken` records if public/API access is required.
- Application lock is a separate current-user security resource, not a second login system hidden in controllers.

Routes:

- `resources :sessions, only: [:index, :destroy]` for user-visible session management if backed by persisted sessions/tokens.
- `resource :two_factor_authentication`
- `resource :application_lock`
- `resources :external_authentications, only: [:index, :destroy]`

Verification:

- Integration tests for auth-required routes.
- Security tests for user-owned resources and token revocation.
- System tests for the primary 2FA/application-lock flows once implemented.

### Phase 6: Attachments, Maps, PWA, And Mobile-Responsive UI

目标是替代交易图片、地图位置、PWA 和移动端关键页面。

Architecture:

- Transaction pictures use Active Storage. Production storage remains Cloudflare R2 through ENV config, following project R2 rules.
- Map tile/proxy requests are external I/O and should use adapter/job/cache boundaries where possible. Inline proxying is an explicit exception only if documented with timeout, cache, rate limit, and failure behavior.
- PWA files stay in Rails views/assets, not a separate Vue build.
- UI is one responsive Rails/Hotwire interface first; mobile-only routes are added only when the UX concept is genuinely different.

Verification:

- Active Storage attachment tests for upload/removal ownership.
- System tests for add/edit transaction with picture when JavaScript is needed.
- Visual checks for desktop and mobile breakpoints.

### Phase 7: Scheduled Transactions And Automation

目标是替代交易模板、周期交易和自动创建交易。

Entities:

- `TransactionTemplate` for normal templates and scheduled templates.
- Schedule fields use explicit columns for frequency type, frequency values, start/end dates, schedule time, and timezone offset. JSONB is not the source of truth for schedule behavior.

Architecture:

- `ScheduledTransactionCreator#create_due_transactions(current_time:)` runs from Solid Queue recurring jobs.
- It creates transactions through `TransactionRecorder` so balance/tag/account rules remain centralized.
- Failures surface in Solid Queue; no broad rescue that hides broken templates.

Verification:

- Service tests for daily, weekly, monthly, yearly schedules, start/end boundaries, and duplicate prevention.
- Job tests prove failed schedules are visible/retryable.

### Phase 8: API, AI, MCP, And Advanced Integrations

目标是在 Rails 产品可用后覆盖机器接口和 AI 功能。

API strategy:

- Rails canonical routes are resource-oriented HTML/Hotwire routes.
- JSON API lives under `namespace :api do; namespace :v1 do ... end end` and uses top-level response keys.
- API authentication starts with the simplest sufficient strategy for the actual client: Devise session for internal Ajax, HTTP token for service clients, and JWT/OAuth only if a public API requirement exists.
- Legacy ezBookkeeping endpoint compatibility is an adapter layer only if existing clients must keep working. It should not dictate internal Rails routes or models.

AI and MCP strategy:

- Receipt image recognition is external LLM I/O: Controller -> Job -> persisted recognition result -> Turbo/Action Cable update.
- MCP server support is added only after API token and resource authorization boundaries are implemented.
- MCP tool definitions map to approved service methods. Do not store executable tool handlers in database rows.

Verification:

- API integration tests for authentication, content negotiation, response shape, and user scoping.
- Job tests for LLM request lifecycle, failure status, retry/no-retry behavior, and absence of open DB transactions during external calls.
- MCP tests only after tool/resource contract is documented.

## Data Model Principles

- Use Postgres constraints as the integrity source of truth: `null:` and `comment:` on every migration column, foreign keys, check constraints, and unique indexes.
- Use lookup tables when values may expand or need metadata. Use Rails enums only for hardcoded workflow choices that are stable.
- Use `has_prefix_id` for models exposed in URLs or public JSON unless a phase explicitly implements a legacy compatibility adapter.
- Use `discarded_at` and the `discard` gem for soft-deletable user-owned ledger models; do not add `default_scope` manually.
- Money is integer cents. Exchange-rate factors use integer scaled values only when precision rules require it.
- JSONB is allowed for display/config snapshots and import raw rows, but not for ownership, money, workflow status, permissions, or frequently queried ledger facts.
- Core business workflows live in services, not Active Record callbacks or fat models.

## UI Principles

- Server-side rendering is the default. Turbo Frames/Streams cover dynamic updates.
- Flowbite semantic color classes are required; avoid hardcoded Tailwind colors and `dark:` overrides.
- Existing components (`ButtonComponent`, `FormField::InputComponent`, `FormField::CheckboxComponent`, `FlashComponent`, `ModalComponent`) are preferred before writing repeated class strings.
- Forms show inline errors and use `status: :unprocessable_content` on failed submissions.
- Destructive confirmations use Flowbite modal patterns.
- Use semantic selectors in system tests; add `data-testid` only after real test instability appears.

## Routing Principles

- Add canonical resource routes before any vanity or compatibility URL.
- Query params handle filtering, sorting, search, tab, and date state.
- Custom actions are exceptions. Prefer named resources such as `data_exports#create`, `ledger_clearance#create`, or `transaction_imports#create` over action-focused routes.
- Do not deeply nest resources. User ownership is loaded through `current_user`, not `/users/:user_id/...` routes.

## Testing And Verification Gates

Every phase must define the concrete regression risk before adding tests. Use the narrowest layer that covers the risk:

- Model tests: database constraints, non-trivial validations, observable callbacks.
- Service tests: ledger balance rules, statistics, import workflows, scheduled transactions, external orchestration boundaries.
- Integration tests: authentication, authorization, status codes, JSON response shape, HTTP parameter coercion.
- System tests: primary user flows and JavaScript/browser integration.
- Factory lint: factory validity once factories exist.

Minimum gates by change type:

- Model/controller changes: `bin/rails test`.
- System/UI changes: relevant system test or visual check plus `bin/rubocop` and `bundle exec erb_lint --lint-all`.
- Component changes: preview check at `/lookbook` plus `bin/rails test`.
- Pre-merge: `bin/ci`.

## Rollout Strategy

1. Complete Phase 0 parity inventory before implementing broad feature work.
2. Implement Phase 1 in vertical slices: accounts, categories, tags, transactions, dashboard.
3. After each slice, migrate only the data needed for that slice and verify user flows in Rails.
4. Keep source Go/Vue project read-only as behavioral reference during rewrite.
5. Cut over only when Rails covers the user-visible workflows in the chosen release scope and migration validation passes.
6. Delete obsolete compatibility adapters when no active client or migration path needs them.

## Open Decisions

These need explicit decisions before their implementation phases, but they do not block Phase 0 or Phase 1 planning:

- Whether Rails must preserve legacy numeric IDs in public JSON, or can expose prefixed Rails IDs only.
- Which import formats are required for first production cutover.
- Which exchange-rate providers matter for this deployment.
- Whether OIDC beyond GitHub is required, and which providers must be supported.
- Whether MCP is a production requirement or an advanced post-cutover integration.
- Whether the first Rails UI must match source desktop/mobile layouts exactly or can be Rails-native responsive UI with equivalent functionality.

## First Implementation Plan To Write After This Design

After this design is approved, the first implementation plan should be Phase 0 plus the first Phase 1 vertical slice:

1. Build parity inventory docs/scripts.
2. Add `Account` and opening-balance transaction foundations.
3. Add account index/new/create UI.
4. Verify with service, DB constraint, integration, and narrow system tests.

This creates a small, testable Rails foundation before expanding into all ledger features.
