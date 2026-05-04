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
