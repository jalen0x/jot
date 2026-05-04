require "csv"

class TransactionImporter
  class ImportError < StandardError; end

  def import_transactions(import_batch:)
    imported_count = 0

    CSV.parse(import_batch.raw_csv, headers: true).each do |row|
      record_row(import_batch.user, row)
      imported_count += 1
    end

    import_batch.update!(status: :imported, imported_count: imported_count, error_message: "")
  rescue CSV::MalformedCSVError => error
    raise ImportError, error.message
  end

  private

  def record_row(user, row)
    account = find_account(user, row.fetch("Account"))
    destination_account = row["Destination Account"].present? ? find_account(user, row["Destination Account"]) : nil
    category = find_category(user, row.fetch("Category"))
    tag_ids = tag_ids(user, row["Tags"])

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: {
        transaction_kind: row.fetch("Type"),
        account_id: account.id.to_s,
        destination_account_id: destination_account&.id.to_s,
        transaction_category_id: category.id.to_s,
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
    raise ImportError, "Account not found: #{name}"
  end

  def find_category(user, name)
    user.transaction_categories.kept.find_by!(name: name)
  rescue ActiveRecord::RecordNotFound
    raise ImportError, "Category not found: #{name}"
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
