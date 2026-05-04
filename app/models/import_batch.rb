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
  validate :source_filename_must_be_supported_format

  def as_json(_options = {})
    {
      id: to_param,
      source_filename: source_filename,
      status: status,
      imported_count: imported_count,
      error_message: error_message
    }
  end

  private

  def source_filename_must_be_supported_format
    return if source_filename.blank?
    return if source_filename.to_s.downcase.end_with?(".csv", ".tsv", ".json")

    errors.add(:source_filename, "must be csv, tsv, or json")
  end
end
