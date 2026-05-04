require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get accounts_path

    assert_redirected_to new_user_session_path
  end

  test "lists only current user accounts" do
    user = create(:user)
    other_user = create(:user)
    own_account = create_account(user: user, name: "Checking", balance_cents: 12_300)
    create_account(user: other_user, name: "Other Checking")

    sign_in user
    get accounts_path

    assert_response :success
    assert_select "h1", text: /accounts/i
    assert_select "li", text: /#{own_account.name}/i
    assert_select "li", text: /123.00 USD/
    assert_select "li", text: /Other Checking/i, count: 0
  end

  test "creates an account for current user" do
    user = create(:user)
    sign_in user

    post accounts_path, params: {
      account: {
        name: "Cash",
        account_category: "cash",
        account_structure: "single_account",
        icon_key: "1",
        color_hex: "22C55E",
        currency_code: "USD",
        opening_balance_cents: "1234",
        comment: "Wallet"
      }
    }

    account = user.accounts.sole
    assert_redirected_to accounts_path
    assert_equal "Cash", account.name
    assert_equal 1234, account.balance_cents
  end

  private

  def create_account(user:, name:, balance_cents: 0)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "2563EB",
      currency_code: "USD",
      balance_cents: balance_cents,
      display_order: 1
    )
  end
end
