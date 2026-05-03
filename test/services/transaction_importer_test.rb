require "test_helper"

class TransactionImporterTest < ActiveSupport::TestCase
  test "imports exported transaction rows through TransactionRecorder" do
    user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    create_tag(user: user, name: "Business")
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: csv_for(comment: "Client lunch"))

    TransactionImporter.new.import_transactions(import_batch: batch)

    assert_predicate batch.reload, :imported?
    assert_equal 1, batch.imported_count
    transaction = user.transactions.sole
    assert_equal "Client lunch", transaction.comment
    assert_equal [ "Business" ], transaction.transaction_tags.map(&:name)
    assert_equal 3_800, account.reload.balance_cents
  end

  test "raises import error when account is missing" do
    user = create(:user)
    create_category(user: user, name: "Food", category_type: :expense)
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: csv_for(comment: "Client lunch"))

    error = assert_raises(TransactionImporter::ImportError) do
      TransactionImporter.new.import_transactions(import_batch: batch)
    end

    assert_equal "Account not found: Cash", error.message
    assert_empty user.transactions
  end

  private

  def csv_for(comment:)
    <<~CSV
      Transacted At,Type,Account,Destination Account,Category,Source Amount Cents,Destination Amount Cents,Tags,Comment
      2026-05-03T10:00:00Z,expense,Cash,,Food,1200,0,Business,#{comment}
    CSV
  end

  def create_account(user:, name:, balance_cents:)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_category(user:, name:, category_type:)
    TransactionCategory.create!(
      user: user,
      name: name,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end
end
