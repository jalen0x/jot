class AddNumberFormatToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :number_format, :text, null: false, default: "western", comment: "Preferred decimal and grouping symbols for signed-in number text"

    add_check_constraint :user_preferences,
      "number_format IN ('western', 'decimal_comma')",
      name: "user_preferences_number_format_supported"
  end
end
