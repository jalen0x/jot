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
    assert_select "form[action='#{account_path(own_account)}'][data-turbo-confirm]"
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

  test "updates an account for current user without changing its balance" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 12_300)
    sign_in user

    get edit_account_path(account)
    assert_response :success
    assert_select "h1", text: /edit account/i
    assert_select "input#account_opening_balance_cents", count: 0

    patch account_path(account), params: {
      account: {
        name: "Everyday Checking",
        account_category: "savings_account",
        account_structure: "single_account",
        icon_key: "3",
        color_hex: "#f97316",
        currency_code: "eur",
        comment: "Primary account"
      }
    }

    assert_redirected_to accounts_path
    account.reload
    assert_equal "Everyday Checking", account.name
    assert_equal "savings_account", account.account_category
    assert_equal "single_account", account.account_structure
    assert_equal 3, account.icon_key
    assert_equal "F97316", account.color_hex
    assert_equal "EUR", account.currency_code
    assert_equal "Primary account", account.comment
    assert_equal 12_300, account.balance_cents
  end

  test "does not update another user's account" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: other_user, name: "Other Checking", balance_cents: 50_000)
    sign_in user

    patch account_path(account), params: {
      account: {
        name: "Changed",
        account_category: "checking_account",
        account_structure: "single_account",
        icon_key: "3",
        color_hex: "F97316",
        currency_code: "USD",
        comment: "Changed"
      }
    }

    assert_response :not_found
    assert_equal "Other Checking", account.reload.name
    assert_equal 50_000, account.balance_cents
  end

  test "deletes an account for current user" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 12_300)
    sign_in user

    delete account_path(account)

    assert_response :see_other
    assert_redirected_to accounts_path
    assert_predicate account.reload, :discarded?
  end

  test "does not delete another user's account" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: other_user, name: "Other Checking", balance_cents: 50_000)
    sign_in user

    delete account_path(account)

    assert_response :not_found
    assert_predicate account.reload, :kept?
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
