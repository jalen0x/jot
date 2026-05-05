class AddTimeFormatToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences,
      :time_format,
      :text,
      null: false,
      default: "twenty_four_hour",
      comment: "Preferred display format for signed-in time text"

    add_check_constraint :user_preferences,
      "time_format IN ('twenty_four_hour', 'twelve_hour')",
      name: "user_preferences_time_format_supported"
  end
end
