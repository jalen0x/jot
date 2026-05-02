require "csv"

class DataExport
  HEADERS = [
    "Transacted At",
    "Type",
    "Account",
    "Destination Account",
    "Category",
    "Source Amount Cents",
    "Destination Amount Cents",
    "Tags",
    "Comment"
  ].freeze

  def transactions_csv(user:)
    CSV.generate(headers: true) do |csv|
      csv << HEADERS

      user.transactions.kept.includes(:account, :destination_account, :transaction_category, :transaction_tags).order(:transacted_at, :id).each do |transaction|
        csv << row_for(transaction)
      end
    end
  end

  private

  def row_for(transaction)
    [
      transaction.transacted_at.iso8601,
      transaction.transaction_kind,
      transaction.account.name,
      transaction.destination_account&.name,
      transaction.transaction_category.name,
      transaction.source_amount_cents,
      transaction.destination_amount_cents,
      transaction.transaction_tags.map(&:name).join("; "),
      transaction.comment
    ]
  end
end
