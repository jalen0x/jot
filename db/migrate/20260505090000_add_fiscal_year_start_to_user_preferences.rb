class AddFiscalYearStartToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences,
      :fiscal_year_start_month,
      :integer,
      null: false,
      default: 1,
      comment: "Preferred fiscal year start month"
    add_column :user_preferences,
      :fiscal_year_start_day,
      :integer,
      null: false,
      default: 1,
      comment: "Preferred fiscal year start day"

    add_check_constraint :user_preferences,
      fiscal_year_start_constraint,
      name: "user_preferences_fiscal_year_start_valid"
  end

  private

  def fiscal_year_start_constraint
    <<~SQL.squish
      (
        fiscal_year_start_month IN (1, 3, 5, 7, 8, 10, 12)
        AND fiscal_year_start_day BETWEEN 1 AND 31
      )
      OR (
        fiscal_year_start_month IN (4, 6, 9, 11)
        AND fiscal_year_start_day BETWEEN 1 AND 30
      )
      OR (
        fiscal_year_start_month = 2
        AND fiscal_year_start_day BETWEEN 1 AND 28
      )
    SQL
  end
end
