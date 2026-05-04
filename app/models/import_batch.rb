class ImportBatch < ApplicationRecord
  has_prefix_id :imp

  belongs_to :user

  enum :status, {
    pending: 0,
    processing: 1,
    imported: 2,
    failed: 3
  }

  validates :raw_csv, presence: true

  def as_json(_options = {})
    {
      id: to_param,
      source_filename: source_filename,
      status: status,
      imported_count: imported_count,
      error_message: error_message
    }
  end
end
