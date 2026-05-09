class ApplicationLock < ApplicationRecord
  has_secure_password :pin, validations: false

  belongs_to :user

  validates :user_id, uniqueness: true
  validates :pin_digest, presence: true
  validates :pin, presence: true, on: :create
  validates :pin, format: { with: /\A\d{6}\z/ }, allow_blank: true, on: :create
  validate :pin_confirmation_matches, on: :create

  attr_reader :pin_confirmation

  def self.normalize_pin(pin) = pin.to_s.strip

  def pin=(value)
    super(self.class.normalize_pin(value))
  end

  def pin_confirmation=(value)
    @pin_confirmation = self.class.normalize_pin(value)
  end

  def authenticate_pin(value)
    super(self.class.normalize_pin(value))
  end

  def as_json(_options = {})
    {
      enabled: true,
      created_at: created_at.iso8601(3)
    }
  end

  private

  def pin_confirmation_matches
    return if @pin_confirmation.blank?
    return if pin == @pin_confirmation

    errors.add(:pin_confirmation, :confirmation, attribute: ApplicationLock.human_attribute_name(:pin))
  end
end
