# ezBookkeeping Data Migration Map

## Principles

- Rails is the new source of truth after cutover.
- Financial amounts migrate into integer cents.
- User-owned rows must map to a Rails `users.id` owner before ledger rows are imported.
- Legacy numeric IDs may be stored in `legacy_source_id` columns only during migration phases that need reconciliation.
- Import scripts must create Rails rows through the same services used by the UI when business effects matter.

## Source Model Mapping

| Source model | Rails destination | Phase | Notes |
| --- | --- | --- | --- |
| User | User plus selected preferences | 4/5 | Devise already owns authentication fields. Profile/display fields move after Phase 1. |
| TwoFactor | TwoFactorAuthentication records | 5 | Rebuild using Rails-native 2FA; do not copy Go token semantics blindly. |
| TwoFactorRecoveryCode | 2FA recovery code records | 5 | Migrate only if same 2FA implementation supports the stored format. |
| TokenRecord | Rails sessions or ApiToken | 5/8 | Public API and MCP tokens become explicit records when required. |
| Account | accounts | 1 | Preserve hierarchy, category, currency, hidden state, balance, sort order. |
| Transaction | transactions | 1 | Preserve type, account references, time, amounts, comment, location when columns exist. |
| TransactionCategory | transaction_categories | 1 | Preserve hierarchy, type, icon, color, hidden state, sort order. |
| TransactionTagGroup | transaction_tag_groups | 1 | Preserve group name and sort order. |
| TransactionTag | transaction_tags | 1 | Preserve group, name, hidden state, sort order. |
| TransactionTagIndex | transaction_taggings | 1 | Join table between transactions and tags. |
| TransactionTemplate | transaction_templates | 7 | Split normal templates and scheduled rules into explicit columns. |
| TransactionPictureInfo | Active Storage attachments | 6 | Migrate blobs only after storage backend is configured. |
| UserCustomExchangeRate | user_custom_exchange_rates | 4 | Preserve user override rates with documented base-rate conversion. |
| UserApplicationCloudSetting | application cloud settings | 4 | Implement only if the Rails product keeps this feature. |
| UserExternalAuth | external_authentications | 5 | Map provider and external identity into Rails auth model. |
| InsightsExplorer | insight_explorers | 2 | Store bounded chart/filter config JSONB, never executable code. |
