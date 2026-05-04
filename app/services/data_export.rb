require "csv"

class DataExport
  HEADERS = [
    "Transacted At",
    "Timezone UTC Offset Minutes",
    "Type",
    "Account",
    "Destination Account",
    "Category",
    "Source Amount Cents",
    "Destination Amount Cents",
    "Tags",
    "Hide Amount",
    "Comment",
    "Latitude",
    "Longitude"
  ].freeze

  def transactions_csv(user:)
    transactions_delimited(user: user, col_sep: ",")
  end

  def transactions_tsv(user:)
    transactions_delimited(user: user, col_sep: "\t")
  end

  private

  def transactions_delimited(user:, col_sep:)
    CSV.generate(headers: true, col_sep: col_sep) do |csv|
      csv << HEADERS

      user.transactions.kept.includes(:account, :destination_account, :transaction_category, :transaction_tags).order(:transacted_at, :id).each do |transaction|
        csv << row_for(transaction)
      end
    end
  end

  def row_for(transaction)
    [
      transaction.transacted_at.iso8601,
      transaction.timezone_utc_offset_minutes,
      transaction.transaction_kind,
      transaction.account.name,
      transaction.destination_account&.name,
      transaction.transaction_category&.name,
      transaction.source_amount_cents,
      transaction.destination_amount_cents,
      transaction.transaction_tags.map(&:name).join("; "),
      transaction.hide_amount,
      transaction.comment,
      transaction.geo_latitude&.to_s,
      transaction.geo_longitude&.to_s
    ]
  end
end
