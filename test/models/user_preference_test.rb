require "test_helper"

class UserPreferenceTest < ActiveSupport::TestCase
  test "normalizes the default currency code" do
    preference = UserPreference.new(user: create(:user), default_currency_code: " eur ")

    assert_predicate preference, :valid?, preference.errors.full_messages.to_sentence
    assert_equal "EUR", preference.default_currency_code
  end

  test "requires a three-letter default currency code" do
    preference = UserPreference.new(user: create(:user), default_currency_code: "US")

    refute_predicate preference, :valid?
    assert_includes preference.errors[:default_currency_code], "is invalid"
  end

  test "database rejects unsupported locales" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:locale, "fr")
    end
    assert_match(/user_preferences_locale_supported/i, ex.message)
  end

  test "database rejects unsupported date formats" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:date_format, "iso_week")
    end
    assert_match(/user_preferences_date_format_supported/i, ex.message)
  end

  test "database rejects unsupported time formats" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:time_format, "with_seconds")
    end
    assert_match(/user_preferences_time_format_supported/i, ex.message)
  end

  test "database rejects unsupported number formats" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:number_format, "thin_space")
    end
    assert_match(/user_preferences_number_format_supported/i, ex.message)
  end

  test "database rejects unsupported first days of week" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:first_day_of_week, 7)
    end
    assert_match(/user_preferences_first_day_of_week_supported/i, ex.message)
  end

  test "database rejects unsupported fiscal year start dates" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_columns(fiscal_year_start_month: 4, fiscal_year_start_day: 31)
    end
    assert_match(/user_preferences_fiscal_year_start_valid/i, ex.message)
  end

  test "database rejects unsupported fiscal year formats" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:fiscal_year_format, "legacy_default")
    end
    assert_match(/user_preferences_fiscal_year_format_supported/i, ex.message)
  end

  test "database rejects unsupported currency display formats" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:currency_display_format, "symbol_before_amount")
    end
    assert_match(/user_preferences_currency_display_format_supported/i, ex.message)
  end

  test "database rejects unsupported expense amount colors" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:expense_amount_color, "blue")
    end
    assert_match(/user_preferences_expense_amount_color_supported/i, ex.message)
  end

  test "database rejects unsupported income amount colors" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:income_amount_color, "blue")
    end
    assert_match(/user_preferences_income_amount_color_supported/i, ex.message)
  end

  test "database rejects unsupported coordinate display formats" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:coordinate_display_format, "map_tile")
    end
    assert_match(/user_preferences_coordinate_display_format_supported/i, ex.message)
  end

  test "database rejects missing default account references" do
    preference = UserPreference.create!(user: create(:user), default_currency_code: "USD")

    ex = assert_raises(ActiveRecord::StatementInvalid) do
      preference.update_column(:default_account_id, -1)
    end
    assert_match(/foreign key|fk_rails/i, ex.message)
  end

  test "allows only one preference record per user" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    duplicate = UserPreference.new(user: user, default_currency_code: "EUR")

    refute_predicate duplicate, :valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end
end
