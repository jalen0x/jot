class UserPreference < ApplicationRecord
  DATE_FORMATS = {
    "year_month_day" => "%Y-%m-%d",
    "month_day_year" => "%m/%d/%Y",
    "day_month_year" => "%d/%m/%Y"
  }.freeze
  DEFAULT_DATE_FORMAT = "year_month_day"
  SUPPORTED_DATE_FORMATS = DATE_FORMATS.keys.freeze
  SUPPORTED_LOCALES = %w[en zh-CN].freeze

  belongs_to :user

  normalizes :default_currency_code, with: ->(currency) { currency.to_s.strip.upcase }
  normalizes :date_format, with: ->(date_format) { date_format.to_s.strip }
  normalizes :locale, with: ->(locale) { locale.to_s.strip }

  validates :default_currency_code, format: { with: /\A[A-Z]{3}\z/ }
  validates :date_format, inclusion: { in: SUPPORTED_DATE_FORMATS }
  validates :locale, inclusion: { in: SUPPORTED_LOCALES }
  validates :user_id, uniqueness: true

  def self.datetime_format_for(date_format)
    "#{DATE_FORMATS.fetch(date_format)} %H:%M"
  end

  def as_json(_options = {})
    {
      default_currency_code: default_currency_code,
      date_format: date_format,
      locale: locale
    }
  end

  def datetime_format
    self.class.datetime_format_for(date_format)
  end
end
