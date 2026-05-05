class AddTransactionEditScopeToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences,
      :transaction_edit_scope,
      :text,
      null: false,
      default: "all",
      comment: "Preferred date window for editing and deleting transactions"

    add_check_constraint :user_preferences,
      "transaction_edit_scope IN ('none', 'all', 'today_or_later', 'last_24_hours_or_later', 'this_week_or_later', 'this_month_or_later', 'this_year_or_later')",
      name: "user_preferences_transaction_edit_scope_supported"
  end
end
