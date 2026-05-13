require "application_system_test_case"

class TransactionsSystemTest < BrowserSystemTestCase
  test "amount labels and destination fields toggle with transaction kind" do
    user = create(:user, password: "password123")
    sign_in_as(user)

    visit new_transaction_path

    assert_selector "label", text: /\AAmount\z/
    assert_no_selector "label", text: /Source amount/i
    assert_no_selector "label", text: /Destination amount/i

    click_button "Transfer"

    assert_selector "label", text: /Source amount/i
    assert_selector "label", text: /Destination amount/i
  end

  test "source amount input shows currency code of the selected account" do
    user = create(:user, password: "password123")
    create_account(user: user, name: "Checking USD", currency_code: "USD")
    create_account(user: user, name: "Savings EUR", currency_code: "EUR")
    create_category(user: user, category_type: :expense)
    sign_in_as(user)

    visit new_transaction_path

    pick_account "Checking USD (USD)"
    within "[data-transaction-form-target='sourceAmountField']" do
      assert_text "USD"
    end

    pick_account "Savings EUR (EUR)"
    within "[data-transaction-form-target='sourceAmountField']" do
      assert_text "EUR"
      assert_no_text "USD"
    end
  end

  test "clicking the new transaction link opens the form inside a modal" do
    user = create(:user, password: "password123")
    create_account(user: user, name: "Cash")
    create_category(user: user, category_type: :expense)
    sign_in_as(user)

    visit transactions_path
    click_link "New transaction", match: :first

    within "#modal_content" do
      assert_selector "form"
      assert_selector "label", text: /\AAmount\z/
    end
  end

  test "amount input evaluates a formula expression when Enter is pressed" do
    user = create(:user, password: "password123")
    create_account(user: user, name: "Cash")
    create_category(user: user, category_type: :expense)
    sign_in_as(user)

    visit new_transaction_path

    fill_in "Amount", with: "12.5+3.8"
    find_field("Amount").send_keys(:return)

    assert_field "Amount", with: "16.3"
  end

  private

  def pick_account(display_name, scope: "[data-transaction-form-target='sourceAccount']")
    within scope do
      button = find("button[data-combobox-target='button']")
      button.click
      button.click unless has_selector?("div[data-combobox-target='panel']:not([hidden])", wait: 1)
      find("li[data-combobox-target='option']", text: display_name).click
    end
  end

  def create_account(user:, name:, currency_code: "USD", balance_cents: 0)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_category(user:, category_type:)
    TransactionCategory.create!(
      user: user,
      name: category_type.to_s.humanize,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
