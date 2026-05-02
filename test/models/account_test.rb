require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "belongs to a user" do
    user = create(:user)
    account = Account.create!(
      user: user,
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )

    assert_equal user, account.user
  end

  test "database rejects an account without an owner" do
    account = Account.create!(
      user: create(:user),
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )

    error = assert_raises(ActiveRecord::NotNullViolation) do
      account.update_column(:user_id, nil)
    end

    assert_match(/user_id/i, error.message)
  end

  test "normalizes color and currency fields" do
    account = Account.create!(
      user: create(:user),
      name: "  Cash  ",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "#22c55e",
      currency_code: "usd",
      balance_cents: 0,
      display_order: 1
    )

    assert_equal "Cash", account.name
    assert_equal "22C55E", account.color_hex
    assert_equal "USD", account.currency_code
  end
end
