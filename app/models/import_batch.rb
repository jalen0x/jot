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
end
