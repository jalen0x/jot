class ImportBatchParserJob < ApplicationJob
  discard_on ActiveRecord::RecordNotFound

  def perform(import_batch_id)
    import_batch = ImportBatch.find(import_batch_id)
    return if import_batch.imported?

    import_batch.update!(status: :processing)
    ImportFileParser.new.parse_import_batch(import_batch: import_batch)
    TransactionImporter.new.import_transactions(import_batch: import_batch)
  rescue ImportFileParser::ParseError, TransactionImporter::ImportError => error
    import_batch.update!(status: :failed, error_message: error.message)
    raise
  end
end
