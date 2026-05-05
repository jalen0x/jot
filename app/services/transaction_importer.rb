class TransactionImporter
  class ImportError < StandardError; end

  def import_transactions(import_batch:)
    imported_count = 0

    ActiveRecord::Base.transaction do
      import_batch.parsed_rows.each do |row|
        record_row(import_batch.user, row)
        imported_count += 1
      end

      import_batch.update!(status: :imported, imported_count: imported_count, error_message: "")
    end
  end

  private

  def record_row(user, row)
    transaction_kind = row_field(row, "Type")
    account = find_account(user, row_field(row, "Account"))
    destination_account = row["Destination Account"].present? ? find_account(user, row["Destination Account"]) : nil
    category = transaction_kind == "balance_adjustment" ? nil : find_category(user, row_field(row, "Category"))
    tag_ids = tag_ids(user, row["Tags"])

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: {
        transaction_kind: transaction_kind,
        account_id: account.id.to_s,
        destination_account_id: destination_account&.id.to_s,
        transaction_category_id: category&.id&.to_s,
        transacted_at: row_field(row, "Transacted At"),
        timezone_utc_offset_minutes: row["Timezone UTC Offset Minutes"] || "0",
        source_amount_cents: row_field(row, "Source Amount Cents"),
        destination_amount_cents: row_field(row, "Destination Amount Cents"),
        hide_amount: row["Hide Amount"] || "0",
        comment: row["Comment"],
        geo_latitude: row["Latitude"],
        geo_longitude: row["Longitude"]
      },
      tag_ids: tag_ids
    )

    raise ImportError, result.transaction.errors.full_messages.to_sentence unless result.recorded?
  end

  def row_field(row, key)
    raise ImportError, "Import row must be an object" unless row.respond_to?(:fetch)

    row.fetch(key)
  rescue KeyError
    raise ImportError, "Import row is missing #{key}"
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
