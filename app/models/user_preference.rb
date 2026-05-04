class UserPreference < ApplicationRecord
  SUPPORTED_LOCALES = %w[en zh-CN].freeze

  belongs_to :user

  normalizes :default_currency_code, with: ->(currency) { currency.to_s.strip.upcase }
  normalizes :locale, with: ->(locale) { locale.to_s.strip }

  validates :default_currency_code, format: { with: /\A[A-Z]{3}\z/ }
  validates :locale, inclusion: { in: SUPPORTED_LOCALES }
  validates :user_id, uniqueness: true

  def as_json(_options = {})
    {
      default_currency_code: default_currency_code,
      locale: locale
    }
  end
end
