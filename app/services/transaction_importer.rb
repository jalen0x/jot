require "csv"
require "json"

class TransactionImporter
  class ImportError < StandardError; end

  def import_transactions(import_batch:)
    imported_count = 0

    ActiveRecord::Base.transaction do
      rows_for(import_batch).each do |row|
        record_row(import_batch.user, row)
        imported_count += 1
      end

      import_batch.update!(status: :imported, imported_count: imported_count, error_message: "")
    end
  rescue CSV::MalformedCSVError, JSON::ParserError => error
    raise ImportError, error.message
  end

  private

  def rows_for(import_batch)
    return json_rows(import_batch) if json_file?(import_batch)

    CSV.parse(import_batch.raw_csv, headers: true, col_sep: column_separator(import_batch))
  end

  def column_separator(import_batch)
    import_batch.source_filename.to_s.downcase.end_with?(".tsv") ? "\t" : ","
  end

  def json_file?(import_batch)
    import_batch.source_filename.to_s.downcase.end_with?(".json")
  end

  def json_rows(import_batch)
    payload = JSON.parse(import_batch.raw_csv)
    transactions = payload["transactions"] if payload.is_a?(Hash)
    raise ImportError, "JSON import must include a transactions array" unless transactions.is_a?(Array)

    transactions.map do |row|
      {
        "Transacted At" => json_field(row, "transacted_at"),
        "Timezone UTC Offset Minutes" => row["timezone_utc_offset_minutes"] || "0",
        "Type" => json_field(row, "transaction_kind"),
        "Account" => json_field(row, "account_name"),
        "Destination Account" => row["destination_account_name"],
        "Category" => row["transaction_category_name"],
        "Source Amount Cents" => json_field(row, "source_amount_cents"),
        "Destination Amount Cents" => row["destination_amount_cents"] || "0",
        "Tags" => Array(row["transaction_tag_names"]).join("; "),
        "Hide Amount" => row["hide_amount"] || "0",
        "Comment" => row["comment"],
        "Latitude" => row["geo_latitude"],
        "Longitude" => row["geo_longitude"]
      }
    end
  end

  def json_field(row, key)
    row.fetch(key)
  rescue KeyError
    raise ImportError, "JSON transaction is missing #{key}"
  end

  def record_row(user, row)
    transaction_kind = row.fetch("Type")
    account = find_account(user, row.fetch("Account"))
    destination_account = row["Destination Account"].present? ? find_account(user, row["Destination Account"]) : nil
    category = transaction_kind == "balance_adjustment" ? nil : find_category(user, row.fetch("Category"))
    tag_ids = tag_ids(user, row["Tags"])

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: {
        transaction_kind: transaction_kind,
        account_id: account.id.to_s,
        destination_account_id: destination_account&.id.to_s,
        transaction_category_id: category&.id&.to_s,
        transacted_at: row.fetch("Transacted At"),
        timezone_utc_offset_minutes: row["Timezone UTC Offset Minutes"] || "0",
        source_amount_cents: row.fetch("Source Amount Cents"),
        destination_amount_cents: row.fetch("Destination Amount Cents"),
        hide_amount: row["Hide Amount"] || "0",
        comment: row["Comment"],
        geo_latitude: row["Latitude"],
        geo_longitude: row["Longitude"]
      },
      tag_ids: tag_ids
    )

    raise ImportError, result.transaction.errors.full_messages.to_sentence unless result.recorded?
  end

  def find_account(user, name)
    user.accounts.kept.find_by!(name: name)
  rescue ActiveRecord::RecordNotFound
    raise ImportError, "Account not found: #{name}", cause: nil
  end

  def find_category(user, name)
    user.transaction_categories.kept.find_by!(name: name)
  rescue ActiveRecord::RecordNotFound
    raise ImportError, "Category not found: #{name}", cause: nil
  end

  def tag_ids(user, value)
    names = value.to_s.split(";").map(&:strip).reject(&:blank?)
    tags = user.transaction_tags.kept.where(name: names).to_a
    found_names = tags.map(&:name)
    missing_names = names - found_names
    raise ImportError, "Tags not found: #{missing_names.to_sentence}" if missing_names.any?

    tags.map { |tag| tag.id.to_s }
  end
end
