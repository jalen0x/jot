class AddParsedRowsToImportBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :import_batches, :parsed_rows, :jsonb, comment: "Parsed import row snapshots prepared for transaction import"
    change_column_comment :import_batches, :raw_csv, "Raw uploaded CSV, TSV, or JSON payload"
  end
end
