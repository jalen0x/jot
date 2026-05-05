require "csv"
require "json"

class ImportFileParser
  class ParseError < StandardError; end

  def parse_import_batch(import_batch:)
    import_batch.update!(parsed_rows: rows_for(import_batch))
  rescue CSV::MalformedCSVError, JSON::ParserError => error
    raise ParseError, error.message
  end

  private

  def rows_for(import_batch)
    return json_rows(import_batch) if json_file?(import_batch)

    CSV.parse(import_batch.raw_csv, headers: true, col_sep: column_separator(import_batch)).map(&:to_h)
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
    raise ParseError, "JSON import must include a transactions array" unless transactions.is_a?(Array)

    transactions.map { |row| json_row(row) }
  end

  def json_row(row)
    raise ParseError, "JSON transaction must be an object" unless row.is_a?(Hash)

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

  def json_field(row, key)
    row.fetch(key)
  rescue KeyError
    raise ParseError, "JSON transaction is missing #{key}"
  end
end
