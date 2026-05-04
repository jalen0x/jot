require "test_helper"

class LedgerClearanceTest < ActiveSupport::TestCase
  test "clears current user's transactions and resets account balances" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 4_500)
    other_account = create_account(user: other_user, name: "Other Cash", balance_cents: 7_000)
    category = create_category(user: user, category_type: :expense)
    tag_group = create_tag_group(user: user)
    tag = create_tag(user: user, tag_group: tag_group)
    transaction = create_transaction(user: user, account: account, category: category)
    create_tagging(user: user, transaction: transaction, tag: tag)
    other_transaction = create_transaction(user: other_user, account: other_account, category: create_category(user: other_user, category_type: :expense))

    LedgerClearance.new.clear_transactions(user: user)

    assert_predicate transaction.reload, :discarded?
    assert_equal 0, account.reload.balance_cents
    assert_equal 0, TransactionTagging.where(user: user).count
    assert_predicate category.reload, :kept?
    assert_predicate tag.reload, :kept?
    assert_predicate tag_group.reload, :kept?
    assert_predicate other_transaction.reload, :kept?
    assert_equal 7_000, other_account.reload.balance_cents
  end

  test "clears all current user's ledger data without touching another user" do
    user = create(:user)
    other_user = create(:user)
    parent_account = create_account(user: user, name: "Parent", account_structure: :multi_sub_accounts)
    account = create_account(user: user, name: "Cash", balance_cents: 4_500, parent_account: parent_account)
    other_account = create_account(user: other_user, name: "Other Cash", balance_cents: 7_000)
    parent_category = create_category(user: user, name: "Bills", category_type: :expense)
    category = create_category(user: user, name: "Utilities", category_type: :expense, parent_category: parent_category)
    tag_group = create_tag_group(user: user)
    tag = create_tag(user: user, tag_group: tag_group)
    exchange_rate = UserCustomExchangeRate.create!(user: user, currency_code: "EUR", rate: "1.25")
    explorer = InsightExplorer.create!(user: user, name: "Monthly", config: {}, display_order: 1)
    template = create_template(user: user, account: account, category: category, tag: tag, name: "Rent")
    transaction = create_transaction(user: user, account: account, category: category)
    create_tagging(user: user, transaction: transaction, tag: tag)
    other_category = create_category(user: other_user, category_type: :expense)
    other_tag_group = create_tag_group(user: other_user)
    other_tag = create_tag(user: other_user, tag_group: other_tag_group)
    other_explorer = InsightExplorer.create!(user: other_user, name: "Other Monthly", config: {}, display_order: 1)
    other_template = create_template(user: other_user, account: other_account, category: other_category, tag: other_tag, name: "Other Rent")
    other_transaction = create_transaction(user: other_user, account: other_account, category: other_category)

    LedgerClearance.new.clear_all_data(user: user)

    assert_equal 0, TransactionTagging.where(user: user).count
    assert_equal 0, TransactionTemplateTagging.where(user: user).count
    assert_predicate transaction.reload, :discarded?
    assert_predicate account.reload, :discarded?
    assert_predicate parent_account.reload, :discarded?
    assert_equal 0, account.balance_cents
    assert_predicate category.reload, :discarded?
    assert_predicate parent_category.reload, :discarded?
    assert_predicate tag.reload, :discarded?
    assert_predicate tag_group.reload, :discarded?
    assert_predicate exchange_rate.reload, :discarded?
    assert_predicate explorer.reload, :discarded?
    assert_predicate template.reload, :discarded?
    assert_predicate other_transaction.reload, :kept?
    assert_predicate other_account.reload, :kept?
    assert_predicate other_category.reload, :kept?
    assert_predicate other_explorer.reload, :kept?
    assert_predicate other_template.reload, :kept?
    assert_equal 1, TransactionTemplateTagging.where(user: other_user).count
  end

  private

  def create_account(user:, name:, balance_cents: 0, account_structure: :single_account, parent_account: nil)
    Account.create!(
      user: user,
      parent_account: parent_account,
      name: name,
      account_category: :cash,
      account_structure: account_structure,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_category(user:, category_type:, name: category_type.to_s.humanize, parent_category: nil)
    TransactionCategory.create!(
      user: user,
      parent_category: parent_category,
      name: name,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_tag_group(user:)
    TransactionTagGroup.create!(user: user, name: "Project", display_order: 1)
  end

  def create_tag(user:, tag_group:)
    TransactionTag.create!(user: user, transaction_tag_group: tag_group, name: "Client", display_order: 1)
  end

  def create_template(user:, account:, category:, tag:, name:)
    template = TransactionTemplate.create!(
      user: user,
      account: account,
      transaction_category: category,
      template_kind: :normal,
      transaction_kind: :expense,
      name: name,
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      schedule_frequency: :disabled,
      schedule_rule: "",
      scheduled_at_minutes: 540,
      timezone_utc_offset_minutes: 0,
      display_order: 1
    )
    template.transaction_template_taggings.create!(user: user, transaction_tag: tag)
    template
  end

  def create_transaction(user:, account:, category:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      comment: "Clear me"
    )
  end

  def create_tagging(user:, transaction:, tag:)
    TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag)
  end
end
