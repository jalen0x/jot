# ezBookkeeping Data Migration Map

## Principles

- Rails is the new source of truth after cutover.
- Financial amounts migrate into integer cents.
- User-owned rows must map to a Rails `users.id` owner before ledger rows are imported.
- Legacy numeric IDs are migration-only inputs. Public URLs and JSON expose Rails prefixed IDs.
- Import scripts must create Rails rows through the same services used by the UI when business effects matter.

## Source Model Mapping

| Source model | Rails destination | Phase | Notes |
| --- | --- | --- | --- |
| User | User plus selected preferences | 4/5 | Devise already owns authentication fields. Profile/display fields move after Phase 1. |
| TwoFactor | TwoFactorAuthentication records | 5 | Rebuild using Rails-native 2FA; do not copy Go token semantics blindly. |
| TwoFactorRecoveryCode | 2FA recovery code records | 5 | Migrate only if same 2FA implementation supports the stored format. |
| TokenRecord | Rails sessions or ApiToken | 5/8 | Public API tokens become explicit records when required. MCP token semantics are not migrated. |
| Account | accounts | 1 | Preserve hierarchy, category, currency, hidden state, balance, sort order. |
| Transaction | transactions | 1 | Preserve type, account references, time, amounts, comment, location when columns exist. |
| TransactionCategory | transaction_categories | 1 | Preserve hierarchy, type, icon, color, hidden state, sort order. |
| TransactionTagGroup | transaction_tag_groups | 1 | Preserve group name and sort order. |
| TransactionTag | transaction_tags | 1 | Preserve group, name, hidden state, sort order. |
| TransactionTagIndex | transaction_taggings | 1 | Join table between transactions and tags. |
| TransactionTemplate | transaction_templates | 7 | Split normal templates and scheduled rules into explicit columns. |
| TransactionPictureInfo | Active Storage attachments | 6 | Migrate blobs only after storage backend is configured. |
| UserCustomExchangeRate | user_custom_exchange_rates | 4 | Preserve user override rates with documented base-rate conversion. |
| UserApplicationCloudSetting | Excluded | Excluded | Old frontend local UI setting sync is not migrated. Durable Rails preferences live in `UserPreference` or explicit Rails resources. |
| UserExternalAuth | `users.provider` / `users.uid` exposed through `ExternalAuthentication` | 5 | Preserve only GitHub links that can be safely represented by Devise OmniAuth. Non-GitHub OIDC/Gitea/Nextcloud links are deferred and require re-linking if those providers become product requirements. |
| InsightsExplorer | insight_explorers | 2 | Store bounded chart/filter config JSONB, never executable code. |
