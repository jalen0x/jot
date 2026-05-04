class ExchangeRateSnapshot < ApplicationRecord
  SCALE = UserCustomExchangeRate::SCALE

  normalizes :data_source, with: ->(data_source) { data_source.to_s.strip }
  normalizes :base_currency_code, :currency_code, with: ->(currency) { currency.to_s.strip.upcase }
  normalizes :reference_url, with: ->(reference_url) { reference_url.to_s.strip.presence }

  validates :data_source, :observed_at, presence: true
  validates :base_currency_code, :currency_code, format: { with: /\A[A-Z]{3}\z/ }
  validates :currency_code, uniqueness: { scope: [ :data_source, :base_currency_code, :observed_at ] }
  validates :rate_scaled, numericality: { only_integer: true, greater_than: 0 }
  validate :rate_input_must_be_valid
  validate :currency_must_differ_from_base

  def self.latest_for_base(base_currency_code)
    base_currency_code = base_currency_code.to_s.strip.upcase
    where(base_currency_code: base_currency_code)
      .order(:currency_code, observed_at: :desc, created_at: :desc)
      .group_by(&:currency_code)
      .map { |_currency_code, snapshots| snapshots.first }
  end

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

  private

  def rate_input_must_be_valid
    errors.add(:rate, "is invalid") if @rate_input_invalid
  end

  def currency_must_differ_from_base
    return if base_currency_code.blank? || currency_code.blank?
    return if base_currency_code != currency_code

    errors.add(:currency_code, "must differ from base currency")
  end
end
