class UserCustomExchangeRate < ApplicationRecord
  include Discard::Model

  SCALE = 100_000_000

  has_prefix_id :exr

  belongs_to :user

  normalizes :currency_code, with: ->(currency) { currency.to_s.strip.upcase }

  validates :currency_code, format: { with: /\A[A-Z]{3}\z/ }
  validates :currency_code, uniqueness: { scope: :user_id, conditions: -> { kept } }
  validates :rate_scaled, numericality: { only_integer: true, greater_than: 0 }
  validate :rate_input_must_be_valid
  validate :currency_must_differ_from_default

  def rate
    return if rate_scaled.blank?

    BigDecimal(rate_scaled) / SCALE
  end

  def rate=(value)
    @rate_input_invalid = false
    self.rate_scaled = (BigDecimal(value.to_s.strip) * SCALE).round.to_i
  rescue ArgumentError
    @rate_input_invalid = true
    self.rate_scaled = nil
  end

  def as_json(_options = {})
    {
      id: to_param,
      currency_code: currency_code,
      rate: rate.to_s("F")
    }
  end

  private

  def rate_input_must_be_valid
    errors.add(:rate, "is invalid") if @rate_input_invalid
  end

  def currency_must_differ_from_default
    return if user.blank? || currency_code.blank?
    return if currency_code != default_currency_code

    errors.add(:currency_code, "must differ from default currency")
  end

  def default_currency_code
    user.user_preference&.default_currency_code || "USD"
  end
end
