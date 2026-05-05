class AddCurrencyDisplayFormatToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences,
      :currency_display_format,
      :text,
      null: false,
      default: "code_after_amount",
      comment: "Preferred currency code placement for displayed amounts"

    add_check_constraint :user_preferences,
      "currency_display_format IN ('code_after_amount', 'code_before_amount', 'none')",
      name: "user_preferences_currency_display_format_supported"
  end
end
