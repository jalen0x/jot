class ReceiptRecognition < ApplicationRecord
  has_prefix_id :rec

  belongs_to :user
  has_one_attached :image

  enum :status, {
    pending: 0,
    processing: 1,
    succeeded: 2,
    failed: 3
  }

  validates :status, presence: true
  validate :image_must_be_attached

  def as_json(_options = {})
    {
      id: to_param,
      status: status,
      result: result_json,
      error_message: error_message,
      created_at: created_at.iso8601(3),
      updated_at: updated_at.iso8601(3)
    }
  end

  private

  def image_must_be_attached
    errors.add(:image, "must be attached") unless image.attached?
  end
end
