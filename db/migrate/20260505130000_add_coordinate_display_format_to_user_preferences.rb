class AddCoordinateDisplayFormatToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences,
      :coordinate_display_format,
      :text,
      null: false,
      default: "latitude_longitude_decimal_degrees",
      comment: "Preferred display format for geographic coordinates"

    add_check_constraint :user_preferences,
      "coordinate_display_format IN ('latitude_longitude_decimal_degrees', 'longitude_latitude_decimal_degrees', 'latitude_longitude_decimal_minutes', 'longitude_latitude_decimal_minutes', 'latitude_longitude_degrees_minutes_seconds', 'longitude_latitude_degrees_minutes_seconds')",
      name: "user_preferences_coordinate_display_format_supported"
  end
end
