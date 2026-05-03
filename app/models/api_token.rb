class ApiToken < ApplicationRecord
  include Discard::Model

  has_prefix_id :tok

  belongs_to :user

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true
  validates :token_digest, presence: true

  scope :active, -> { kept.where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.authenticate(raw_token)
    active.find_each.find { |api_token| api_token.matches_token?(raw_token) }
  end

  def active?
    !discarded? && (expires_at.blank? || expires_at.future?)
  end

  def matches_token?(raw_token)
    return false if raw_token.blank?

    BCrypt::Password.new(token_digest).is_password?(raw_token)
  rescue BCrypt::Errors::InvalidHash
    false
  end
end
