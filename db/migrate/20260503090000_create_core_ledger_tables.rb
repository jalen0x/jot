class CreateCoreLedgerTables < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, comment: "User-owned ledger accounts" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this account"
      t.references :parent_account, null: true, foreign_key: { to_table: :accounts }, index: true, comment: "Parent account for two-level account hierarchies"
      t.integer :account_category, null: false, comment: "Account category code from ezBookkeeping"
      t.integer :account_structure, null: false, comment: "Account structure code: single or multi-sub-account"
      t.text :name, null: false, comment: "Human-readable account name"
      t.integer :display_order, null: false, default: 0, comment: "User-controlled display order"
      t.integer :icon_key, null: false, comment: "Icon identifier from the account icon catalog"
      t.text :color_hex, null: false, comment: "Six-character RGB hex color without #"
      t.text :currency_code, null: false, comment: "ISO 4217 currency code"
      t.integer :balance_cents, null: false, default: 0, comment: "Current account balance in cents"
      t.text :comment, null: false, default: "", comment: "Optional user note"
      t.boolean :hidden, null: false, default: false, comment: "Whether the account is hidden in normal lists"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :accounts, :discarded_at
    add_index :accounts, [ :user_id, :parent_account_id, :display_order ], name: "index_accounts_on_owner_parent_order"
    add_check_constraint :accounts, "account_category IN (1,2,3,4,5,6,7,8,9)", name: "accounts_category_valid"
    add_check_constraint :accounts, "account_structure IN (1,2)", name: "accounts_structure_valid"
    add_check_constraint :accounts, "char_length(color_hex) = 6", name: "accounts_color_hex_length"
    add_check_constraint :accounts, "char_length(currency_code) = 3", name: "accounts_currency_code_length"
    add_check_constraint :accounts, "parent_account_id IS NULL OR parent_account_id <> id", name: "accounts_parent_not_self"

    create_table :transactions, comment: "User-owned ledger transactions" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this transaction"
      t.references :account, null: false, foreign_key: true, index: true, comment: "Source account affected by this transaction"
      t.references :destination_account, null: true, foreign_key: { to_table: :accounts }, index: true, comment: "Destination account for transfers"
      t.integer :transaction_kind, null: false, comment: "Transaction kind code: balance adjustment, income, expense, transfer"
      t.datetime :transacted_at, null: false, comment: "User-entered transaction timestamp"
      t.integer :timezone_utc_offset_minutes, null: false, default: 0, comment: "User timezone offset at transaction time"
      t.integer :source_amount_cents, null: false, comment: "Source account amount or balance adjustment delta in cents"
      t.integer :destination_amount_cents, null: false, default: 0, comment: "Destination account amount for transfers in cents"
      t.boolean :hide_amount, null: false, default: false, comment: "Whether amount should be hidden in normal UI"
      t.text :comment, null: false, default: "", comment: "Optional user note"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :transactions, :discarded_at
    add_index :transactions, [ :user_id, :transacted_at ], name: "index_transactions_on_owner_time"
    add_check_constraint :transactions, "transaction_kind IN (1,2,3,4)", name: "transactions_kind_valid"
    add_check_constraint :transactions, "source_amount_cents BETWEEN -99999999999 AND 99999999999", name: "transactions_source_amount_range"
    add_check_constraint :transactions, "destination_amount_cents BETWEEN -99999999999 AND 99999999999", name: "transactions_destination_amount_range"
    add_check_constraint :transactions, "transaction_kind = 4 OR destination_account_id IS NULL", name: "transactions_non_transfer_has_no_destination"
    add_check_constraint :transactions, "transaction_kind <> 4 OR destination_account_id IS NOT NULL", name: "transactions_transfer_destination_required"
    add_check_constraint :transactions, "destination_account_id IS NULL OR destination_account_id <> account_id", name: "transactions_destination_differs_from_source"
  end
end
