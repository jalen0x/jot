require "bcrypt"

class ApplicationLock < ApplicationRecord
  belongs_to :user

  validates :pin_digest, presence: true
  validates :user_id, uniqueness: true

  def self.digest(pin)
    BCrypt::Password.create(normalize_pin(pin), cost: bcrypt_cost)
  end

  def self.normalize_pin(pin)
    pin.to_s.strip
  end

  def matches_pin?(pin)
    BCrypt::Password.new(pin_digest).is_password?(self.class.normalize_pin(pin))
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def as_json(_options = {})
    {
      enabled: true,
      created_at: created_at.iso8601(3)
    }
  end

  def self.bcrypt_cost
    Rails.env.test? ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
  end
  private_class_method :bcrypt_cost
end
