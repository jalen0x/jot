class AddAmountColorsToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences,
      :expense_amount_color,
      :text,
      null: false,
      default: "danger",
      comment: "Preferred semantic text color for expense amounts"
    add_column :user_preferences,
      :income_amount_color,
      :text,
      null: false,
      default: "success",
      comment: "Preferred semantic text color for income amounts"

    add_check_constraint :user_preferences,
      "expense_amount_color IN ('success', 'danger', 'warning', 'neutral')",
      name: "user_preferences_expense_amount_color_supported"
    add_check_constraint :user_preferences,
      "income_amount_color IN ('success', 'danger', 'warning', 'neutral')",
      name: "user_preferences_income_amount_color_supported"
  end
end
