class AddFirstDayOfWeekToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences,
      :first_day_of_week,
      :integer,
      null: false,
      default: 0,
      comment: "Preferred first day of week, where Sunday is 0 and Saturday is 6"

    add_check_constraint :user_preferences,
      "first_day_of_week BETWEEN 0 AND 6",
      name: "user_preferences_first_day_of_week_supported"
  end
end
