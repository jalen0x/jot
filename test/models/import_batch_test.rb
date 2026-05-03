require "test_helper"

class ImportBatchTest < ActiveSupport::TestCase
  test "belongs to a user and defaults to pending" do
    batch = ImportBatch.create!(
      user: create(:user),
      source_filename: "transactions.csv",
      raw_csv: "Transacted At,Type\n"
    )

    assert_predicate batch, :pending?
    assert_equal 0, batch.imported_count
    assert_equal "", batch.error_message
  end

  test "database rejects an import batch without an owner" do
    batch = ImportBatch.create!(
      user: create(:user),
      source_filename: "transactions.csv",
      raw_csv: "Transacted At,Type\n"
    )

    error = assert_raises(ActiveRecord::NotNullViolation) do
      batch.update_column(:user_id, nil)
    end

    assert_match(/user_id/i, error.message)
  end
end
