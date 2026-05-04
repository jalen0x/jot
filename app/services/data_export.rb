require "csv"
require "json"

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

  def transactions_json(user:)
    JSON.generate(transactions: transactions_for(user).map { |transaction| json_for(transaction) })
  end

  private

  def transactions_delimited(user:, col_sep:)
    CSV.generate(headers: true, col_sep: col_sep) do |csv|
      csv << HEADERS

      transactions_for(user).each do |transaction|
        csv << row_for(transaction)
      end
    end
  end

  def transactions_for(user)
    user.transactions.kept.includes(:account, :destination_account, :transaction_category, :transaction_tags).order(:transacted_at, :id)
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

  def json_for(transaction)
    {
      transacted_at: transaction.transacted_at.iso8601,
      timezone_utc_offset_minutes: transaction.timezone_utc_offset_minutes,
      transaction_kind: transaction.transaction_kind,
      account_name: transaction.account.name,
      destination_account_name: transaction.destination_account&.name,
      transaction_category_name: transaction.transaction_category&.name,
      source_amount_cents: transaction.source_amount_cents,
      destination_amount_cents: transaction.destination_amount_cents,
      transaction_tag_names: transaction.transaction_tags.map(&:name),
      hide_amount: transaction.hide_amount,
      comment: transaction.comment,
      geo_latitude: transaction.geo_latitude&.to_s,
      geo_longitude: transaction.geo_longitude&.to_s
    }
  end
end
