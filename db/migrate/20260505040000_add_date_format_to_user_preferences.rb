class AddDateFormatToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :date_format, :text, null: false, default: "year_month_day", comment: "Preferred display order for signed-in date text"

    add_check_constraint :user_preferences,
      "date_format IN ('year_month_day', 'month_day_year', 'day_month_year')",
      name: "user_preferences_date_format_supported"
  end
end
