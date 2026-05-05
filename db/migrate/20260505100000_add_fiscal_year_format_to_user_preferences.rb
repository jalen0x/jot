class AddFiscalYearFormatToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    supported_formats = %w[
      start_year_end_year
      start_year_end_short_year
      start_short_year_end_short_year
      end_year
      end_short_year
    ].map { |format| "'#{format}'" }.join(", ")

    add_column :user_preferences,
      :fiscal_year_format,
      :text,
      null: false,
      default: "start_year_end_year",
      comment: "Preferred fiscal year label format"

    add_check_constraint :user_preferences,
      "fiscal_year_format IN (#{supported_formats})",
      name: "user_preferences_fiscal_year_format_supported"
  end
end
