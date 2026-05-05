require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get accounts_path

    assert_redirected_to new_user_session_path
  end

  test "lists only current user accounts" do
    user = create(:user)
    other_user = create(:user)
    own_account = create_account(user: user, name: "Checking", balance_cents: 12_300, hidden: true)
    child_account = create_account(user: user, name: "Vacation Savings", parent_account: own_account)
    create_account(user: other_user, name: "Other Checking")
    create_account(user: other_user, name: "Other Savings Child")

    sign_in user
    get accounts_path

    assert_response :success
    assert_select "h1", text: /accounts/i
    assert_select "li", text: /#{own_account.name}/i
    assert_select "li", text: /#{child_account.name}/i
    assert_select "li", text: /123.00 USD/
    assert_select "li", text: /Hidden/i
    assert_select "li", text: /Other Checking/i, count: 0
    assert_select "li", text: /Other Savings Child/i, count: 0
    assert_select "a[href='#{account_reconciliation_statement_path(own_account)}']", text: /Reconcile/i
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
        hidden: "1",
        comment: "Wallet"
      }
    }

    account = user.accounts.sole
    assert_redirected_to accounts_path
    assert_equal "Cash", account.name
    assert_equal 1234, account.balance_cents
    assert_predicate account, :hidden?
  end

  test "creates a child account for current user's parent account" do
    user = create(:user)
    parent = create_account(user: user, name: "Savings", account_structure: :multi_sub_accounts)
    create_account(user: user, name: "Emergency Fund", parent_account: parent, display_order: 1)
    sign_in user

    post accounts_path, params: {
      account: {
        name: "Vacation Savings",
        account_category: "savings_account",
        account_structure: "single_account",
        parent_account_id: parent.to_param,
        icon_key: "2",
        color_hex: "22C55E",
        currency_code: "USD",
        opening_balance_cents: "5000",
        hidden: "0",
        comment: "Trip fund"
      }
    }

    assert_redirected_to accounts_path
    account = user.accounts.where(name: "Vacation Savings").sole
    assert_equal parent, account.parent_account
    assert_equal 2, account.display_order
    assert_equal 5_000, account.balance_cents
  end

  test "updates an account for current user without changing its balance" do
    user = create(:user)
    parent = create_account(user: user, name: "Savings", account_structure: :multi_sub_accounts)
    child_parent = create_account(user: user, name: "Emergency Fund", parent_account: parent)
    account = create_account(user: user, name: "Checking", balance_cents: 12_300)
    sign_in user

    get edit_account_path(account)
    assert_response :success
    assert_select "h1", text: /edit account/i
    assert_select "select#account_parent_account_id option[value='#{parent.to_param}']", text: /Savings/i
    assert_select "select#account_parent_account_id option[value='#{child_parent.to_param}']", count: 0
    assert_select "input#account_opening_balance_cents", count: 0
    assert_select "input#account_hidden"

    patch account_path(account), params: {
      account: {
        name: "Everyday Checking",
        account_category: "savings_account",
        account_structure: "single_account",
        icon_key: "3",
        color_hex: "#f97316",
        currency_code: "eur",
        parent_account_id: parent.to_param,
        hidden: "1",
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
    assert_equal parent, account.parent_account
    assert_predicate account, :hidden?
    assert_equal "Primary account", account.comment
    assert_equal 12_300, account.balance_cents
  end

  test "does not create an account under a child account" do
    user = create(:user)
    parent = create_account(user: user, name: "Savings", account_structure: :multi_sub_accounts)
    child = create_account(user: user, name: "Vacation Savings", parent_account: parent)
    sign_in user

    post accounts_path, params: {
      account: {
        name: "Nested Savings",
        account_category: "savings_account",
        account_structure: "single_account",
        parent_account_id: child.to_param,
        icon_key: "2",
        color_hex: "22C55E",
        currency_code: "USD",
        opening_balance_cents: "0",
        comment: "Too deep"
      }
    }

    assert_response :not_found
    assert_empty user.accounts.where(name: "Nested Savings")
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

  test "does not create an account under another user's parent account" do
    user = create(:user)
    other_parent = create_account(user: create(:user), name: "Other Savings")
    sign_in user

    post accounts_path, params: {
      account: {
        name: "Vacation Savings",
        account_category: "savings_account",
        account_structure: "single_account",
        parent_account_id: other_parent.to_param,
        icon_key: "2",
        color_hex: "22C55E",
        currency_code: "USD",
        opening_balance_cents: "5000",
        comment: "Trip fund"
      }
    }

    assert_response :not_found
    assert_empty user.accounts.where(name: "Vacation Savings")
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

  test "deletes child accounts with their parent account" do
    user = create(:user)
    other_user = create(:user)
    parent = create_account(user: user, name: "Savings", account_structure: :multi_sub_accounts)
    child = create_account(user: user, name: "Vacation", parent_account: parent)
    other_parent = create_account(user: other_user, name: "Other Savings", account_structure: :multi_sub_accounts)
    other_child = create_account(user: other_user, name: "Other Vacation", parent_account: other_parent)
    sign_in user

    delete account_path(parent)

    assert_response :see_other
    assert_predicate parent.reload, :discarded?
    assert_predicate child.reload, :discarded?
    assert_predicate other_parent.reload, :kept?
    assert_predicate other_child.reload, :kept?
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

  def create_account(user:, name:, balance_cents: 0, hidden: false, parent_account: nil, account_structure: :single_account, display_order: 1)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: account_structure,
      icon_key: 1,
      color_hex: "2563EB",
      currency_code: "USD",
      balance_cents: balance_cents,
      parent_account: parent_account,
      hidden: hidden,
      display_order: display_order
    )
  end
end
