require "test_helper"

class AccountCreatorTest < ActiveSupport::TestCase
  test "creates an account with an opening balance transaction" do
    user = create(:user)

    result = AccountCreator.new.create_account(
      user: user,
      attributes: account_attributes(name: "Cash"),
      opening_balance_cents: 12_345
    )

    assert_predicate result, :created?
    account = result.account
    assert_equal 12_345, account.balance_cents

    transaction = user.transactions.sole
    assert_predicate transaction, :balance_adjustment?
    assert_equal account, transaction.account
    assert_equal 12_345, transaction.source_amount_cents
  end

  test "creates no opening balance transaction for a zero balance" do
    user = create(:user)

    result = AccountCreator.new.create_account(
      user: user,
      attributes: account_attributes(name: "Cash"),
      opening_balance_cents: 0
    )

    assert_predicate result, :created?
    assert_empty user.transactions
  end

  test "returns account errors for invalid attributes" do
    user = create(:user)

    result = AccountCreator.new.create_account(
      user: user,
      attributes: account_attributes(name: ""),
      opening_balance_cents: 0
    )

    refute_predicate result, :created?
    assert_includes result.account.errors[:name], "can't be blank"
  end

  private

  def account_attributes(name:)
    {
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      display_order: 1,
      comment: "Wallet"
    }
  end
end
