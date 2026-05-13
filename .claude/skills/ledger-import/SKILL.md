---
name: ledger-import
description: Convert Chinese payment / bank statements (Alipay CSV, WeChat XLSX, China Merchants Bank PDF) into the jot.jalenx.me ledger's ImportBatch JSON format, then drive the import. Use when the user wants to 记账 / 导入流水 / 导入账单 from 支付宝 / 微信 / 招商银行 / Alipay / WeChat / CMB exports, or bulk-add transactions from financial statements to this Rails ledger app.
---

# ledger-import

Convert exported statements into JSON rows that the app's `ImportFileParser` accepts (`source_filename` ending `.json`, top-level `{"transactions": [...]}`).

## Quick start

```bash
# 1. Put exported files on Desktop (default Chinese-bank names work):
#    ~/Desktop/支付宝交易明细*.csv
#    ~/Desktop/微信支付账单流水文件*.xlsx
#    ~/Desktop/招商银行交易流水*.pdf

# 2. Run converter (uv handles the openpyxl + pdftotext shell-out):
uv run --with openpyxl --no-project python3 \
  .claude/skills/ledger-import/scripts/convert.py

# 3. Output appears under tmp/import/:
#    tmp/import/alipay.json
#    tmp/import/wechat.json
#    tmp/import/cmb.json
#    tmp/import/<source>.skipped.txt   (reason for each dropped row)

# 4. Upload each at /import_batches/new — filename MUST end with .json,
#    paste file contents into the raw_data textarea.
```

## Before first run — edit `scripts/convert.py`

These constants are user-specific (categories / account names depend on what the target user has in their DB):

| Constant | What it controls |
|---|---|
| `ACCOUNT_NAME` | Target account for all imported rows (default `内地账户`) |
| `ALIPAY_CATEGORY_MAP` | Alipay's `交易分类` → your category names |
| `KEYWORD_CATEGORY` | Merchant keyword → category, used as fallback |
| `DEFAULT_EXPENSE_CATEGORY` / `DEFAULT_INCOME_CATEGORY` | Defaults when nothing matches; **must match category_type** |
| `categorize_personal_transfer` | Personal name (`莹莹` in the template) → couple-specific categories like `莹莹❤️` / `❤️莹莹` |
| `CMB_DROP_SUMMARIES` | CMB 摘要 to skip — these duplicate Alipay/WeChat bank-side entries |

**Category-type constraint**: the app's `validate_category_type` requires the category's `category_type` to equal the transaction's `transaction_kind` (income↔income, expense↔expense). Make sure income rows resolve to an income-typed category. The category and account must already exist (`find_by!` will raise `ImportError` otherwise).

## Workflow checklist

- [ ] Target accounts exist (`bin/rails runner 'puts User.first.accounts.kept.pluck(:name)'`)
- [ ] Each category referenced by convert.py exists in the target user's `transaction_categories`, with the correct `category_type`
- [ ] Run converter, scan `<source>.skipped.txt` for unexpected skips (refunds, neutral transfers, dedup drops)
- [ ] Spot-check 10 rows of each `<source>.json` — verify comment is clean and category matches kind
- [ ] Import smallest / safest first (`wechat` totals match the source header exactly), then `alipay`, then `cmb`
- [ ] Cross-currency 付汇 / 跨境扣款 rows: skip in import and create as `transfer` manually — PDF doesn't carry the foreign-currency amount, you need the actual HKD/USD amount from the receiving account's receipt

## Edge cases the converter handles

- **CMB ↔ Alipay/WeChat duplication**: 招行 PDF includes a bank-side line for every Alipay/WeChat payment (`快捷支付`, `银联快捷支付`, `网联收款`, `银联代付`). The converter drops these — you only need them once via the merchant-level Alipay/WeChat export.
- **Refunds / 不计收支 / 中性交易**: Alipay marks refunds as `不计收支`; WeChat marks 零钱↔银行卡 movements as 中性交易. Both are skipped (header totals validate).
- **Multi-line PDF 对手信息**: pdftotext splits the 对手信息 column across lines; the converter attaches each fragment to the nearest data row. Some rows may end up with a "off by one" counterparty line — verify CMB rows you care about.
- **Comment cleanup**: drops source prefix (`[支付宝]`/`[微信]`/`[招行]`), payment instrument, type tag, 8+ digit account/order numbers, and `集团有限公司` / `有限公司` / `（个体工商户）` suffixes. 淘宝闪购 specifically: uses the underlying 商品 (real restaurant) instead of the platform name.

## Schema, format quirks, and rule details

See [REFERENCE.md](REFERENCE.md).
