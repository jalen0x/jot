class AddTransactionCategoryToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_reference :transactions, :transaction_category, null: true, foreign_key: true, index: true, comment: "Category assigned to normal transactions"
    add_index :transactions, [ :user_id, :transaction_category_id, :transacted_at ], name: "index_transactions_on_owner_category_time"
    add_check_constraint :transactions, "transaction_kind = 1 OR transaction_category_id IS NOT NULL", name: "transactions_normal_category_required"
    add_check_constraint :transactions, "transaction_kind <> 1 OR transaction_category_id IS NULL", name: "transactions_balance_adjustment_has_no_category"
  end
end
