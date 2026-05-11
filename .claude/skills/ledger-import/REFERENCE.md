# ledger-import reference

## App import schema

The app's `ImportFileParser.json_row` expects a top-level `transactions` array. Each row maps to:

| Field key (JSON) | Mapped controller param | Required? | Notes |
|---|---|---|---|
| `transacted_at` | `transacted_at` | ✓ | ISO 8601 with timezone offset, e.g. `"2026-05-10T15:25:03+08:00"` |
| `timezone_utc_offset_minutes` | `timezone_utc_offset_minutes` | — | Defaults to `"0"`; pass `480` for `+08:00` |
| `transaction_kind` | `transaction_kind` | ✓ | One of `expense` / `income` / `transfer` / `balance_adjustment` |
| `account_name` | `account_id` (resolved by name) | ✓ | Must match an existing `Account.name` for this user |
| `destination_account_name` | `destination_account_id` | only for `transfer` | |
| `transaction_category_name` | `transaction_category_id` | ✓ unless `balance_adjustment` | Must match an existing `TransactionCategory.name` (and `category_type`) |
| `source_amount_cents` | `source_amount_cents` | ✓ | Integer cents |
| `destination_amount_cents` | `destination_amount_cents` | — | Defaults `"0"`; required for cross-currency `transfer` |
| `comment` | `comment` | — | Free text |
| `transaction_tag_names` | `tag_ids` (resolved by name) | — | Array; semicolon-joined internally; **tags must already exist** |
| `hide_amount` | `hide_amount` | — | Defaults `"0"` |
| `geo_latitude` / `geo_longitude` | — | — | Optional |

The parser is in `app/services/import_file_parser.rb`; the importer is `app/services/transaction_importer.rb`. The whole batch wraps in a single `ActiveRecord::Base.transaction` — one row failing rolls everything in that batch back.

## Source file formats

### 支付宝交易明细 (CSV)

- Encoding: **GBK** (must `iconv -f GBK -t UTF-8` or decode in Python with `errors="replace"`).
- Header is buried after a ~22-line export-info block; find the line starting `交易时间,`, treat rows below as the CSV.
- Columns: `交易时间,交易分类,交易对方,对方账号,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号,商家订单号,备注`.
- `收/支` values: `支出`, `收入`, `不计收支`. The third covers refunds (`退款-...`) and 余额提现; skip — they don't represent real income/expense.
- Header totals validate: count and amount per category should reconcile with the converter's output minus the `不计收支` rows.

### 微信支付账单流水文件 (XLSX)

- Use `openpyxl.load_workbook(data_only=True)` then iterate; header row starts with `交易时间`.
- Columns: `交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注`.
- `收/支` includes a third value `中性交易` (零钱 ↔ 银行卡 transfers, 理财通, 信用卡还款) — skip.
- `交易类型` carries the kind of WeChat operation (`商户消费`, `微信红包（单发）`, `转账`, `扫二维码付款`). Useful for routing red-packets / transfers to personal categories.
- `交易时间` cell may parse as a `datetime` object — `strftime("%Y-%m-%d %H:%M:%S")` to normalize.

### 招商银行交易流水 (PDF)

- Extract with `pdftotext -layout <file> -`. `-layout` preserves column positions.
- Data rows match: `^(YYYY-MM-DD)\s+(CNY|USD|HKD)\s+(-?[\d,]+\.\d{2})\s+([\d,]+\.\d{2})\s+(\S+)\s*(.*)$` — date, currency, signed amount, running balance, 摘要, optional inline counterparty.
- Negative amount → expense; positive → income.
- 对手信息 column WRAPS across multiple lines; pdftotext renders each fragment on its own physical line above/below the data row. The converter tokenizes lines as `DATA` (matches the regex) or `CTX` (contains Chinese or 6+ digit), then assigns all unassigned CTX since the last DATA as the next row's counterparty blob. Imperfect but workable — verify the few rows that matter.
- Header-table noise (`记账日期`, `Transaction`, `Date`, `Currency`, etc.) is filtered by `CMB_HEADER_NOISE`.

## Comment cleanup pipeline

`convert.py` produces the FINAL clean comment directly (no post-import cleanup needed). Rules:

1. **No source prefix.** No `[支付宝]` / `[微信]` / `[招行]` — the category and account already carry that signal.
2. **Subject only.**
   - Alipay/WeChat: take `对方` (counterparty). If `对方 == "淘宝闪购"`, use `商品` (real restaurant) instead and strip the trailing `外卖订单` / `订单` suffix.
   - 招行: keep `摘要 + counterparty name`, drop 8+ digit account / order numbers, drop trailing parenthesis chains like `(自动计提)（新)`.
3. **Strip legal-entity suffixes**: trailing `集团有限公司`, `有限公司`, `（个体工商户）`. Configured in `COMPANY_SUFFIXES`.
4. **Preserve user notes.** Inline parentheses inside `对方` (e.g. `印象长沙(晚上10点前统一发别急)` — a WeChat 转账备注) are kept; only the well-known bank-system type-tags are stripped via `KNOWN_TYPE_PAREN`. (Currently bypassed because we never include the type-tag in the comment in the first place; the regex is kept as a guard.)

## Category routing

Order of resolution per row (in `convert.py`):

1. **Personal name detection.** If `对方` contains a personal-name marker (`莹莹` in the template), route to `categorize_personal_transfer(income, party)` — returns `❤️莹莹` for income, `莹莹❤️` for expense. Customize this function for your own people.
2. **Alipay `交易分类` direct map.** `ALIPAY_CATEGORY_MAP` covers the standard 16-ish Alipay categories.
3. **WeChat `交易类型` heuristics.** Red-packet / 转账 types route to `categorize_personal_transfer` (falls back to `亲友` / `其它` for non-personal counterparties).
4. **CMB summary heuristics.** `工资|代发` → 工资; `转账|代付|行内转账` → personal-transfer router; `ATM|取款` → 其他.
5. **Merchant keyword fallback.** `KEYWORD_CATEGORY` (奶茶 chains, 餐饮 chains, 交通, 话费, 购物, 虚拟服务, etc.).
6. **Default.** `DEFAULT_INCOME_CATEGORY` (`其它`) or `DEFAULT_EXPENSE_CATEGORY` (`其他`).

The app validates `category.category_type == transaction.transaction_kind`. The default routes never produce a mismatch; if you add custom keyword mappings, only put expense-typed categories under expense paths and income-typed under income paths.

## CMB dedup

招行 PDF includes a bank-side line for every Alipay/WeChat-funded transaction (`快捷支付`, `银联快捷支付` ≈ Alipay; `网联收款`, `银联代付` ≈ WeChat). The converter drops these via `CMB_DROP_SUMMARIES` — relying on Alipay/WeChat exports for the merchant-level detail.

Validation: in a typical 2-month period, `网联收款` total ≈ WeChat 中性交易 total (零钱→bank-card cash-out), within rounding error. If those two don't reconcile, something's missing.

## Cross-currency transfers

CMB statements show one side only: `付汇扣客户户口 -¥2000` debits the CNY account, but the PDF carries no info about the HKD landed on the other side. After import:

```ruby
# In rails runner / console:
src = user.accounts.kept.find_by!(name: "内地账户")
dst = user.accounts.kept.find_by!(name: "香港账户")
cat = user.transaction_categories.kept.find_by!(name: "转账")  # category_type: :transfer
TransactionRecorder.new.record_transaction(
  user: user,
  attributes: {
    transaction_kind: "transfer",
    account_id: src.id.to_s,
    destination_account_id: dst.id.to_s,
    transaction_category_id: cat.id.to_s,
    transacted_at: "2026-05-07 00:00:00",
    timezone_utc_offset_minutes: "480",
    source_amount_cents: "200000",        # ¥2000 CNY
    destination_amount_cents: "229000",   # HK$2290 — get this from receiving-account receipt
    hide_amount: "0",
    comment: "付汇扣客户户口"
  },
  tag_ids: []
)
```

`Transaction` requires a category for every non-`balance_adjustment` row. If no `transfer`-typed category exists yet, create one once:

```ruby
user.transaction_categories.kept.find_or_create_by!(name: "转账", category_type: :transfer) do |c|
  c.icon_key = 4
  c.color_hex = "6B7280"
  c.display_order = (user.transaction_categories.maximum(:display_order) || 0) + 1
end
```

## Driving the import programmatically

Skip the `/import_batches/new` UI for bulk runs:

```ruby
user = User.find_by!(email: "...")
%w[wechat alipay cmb].each do |source|
  content = Rails.root.join("tmp/import/#{source}.json").read
  batch = user.import_batches.create!(source_filename: "#{source}.json", raw_csv: content)
  ImportBatchParserJob.perform_now(batch.id)
  batch.reload
  puts "#{source}: status=#{batch.status} imported=#{batch.imported_count} error=#{batch.error_message}"
end
```

`ImportBatchParserJob` runs `ImportFileParser` then `TransactionImporter`. Failed batches surface the error in `batch.error_message`; nothing is partially committed.

## When something fails

- `Category not found: X` — the row's category name doesn't match any of the user's kept categories. Either add the category or change the converter's mapping.
- `Account not found: X` — `ACCOUNT_NAME` in convert.py doesn't match a real account; update it.
- `Tags not found: ...` — `transaction_tag_names` references a tag that doesn't exist. Either create the tag or remove it from output.
- `Transaction category does not match transaction type` — income row routed to an expense category (or vice versa). Check `categorize_personal_transfer` and `KEYWORD_CATEGORY` for the offending mapping; income paths must yield income-typed categories.
