class TwoFactorRecoveryCode < ApplicationRecord
  belongs_to :user

  validates :code_digest, presence: true

  scope :unused, -> { where(used_at: nil) }

  def self.digest(raw_code)
    BCrypt::Password.create(normalize(raw_code), cost: bcrypt_cost)
  end

  def self.normalize(raw_code)
    raw_code.to_s.strip.downcase
  end

  def used? = used_at.present?

  def matches_code?(raw_code)
    return false if raw_code.blank?

    BCrypt::Password.new(code_digest).is_password?(self.class.normalize(raw_code))
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def self.bcrypt_cost
    ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
  end
  private_class_method :bcrypt_cost

  def consume!(raw_code)
    return false if used? || !matches_code?(raw_code)

    update!(used_at: Time.current)
  end
end
