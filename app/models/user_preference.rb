class UserPreference < ApplicationRecord
  DATE_FORMATS = {
    "year_month_day" => "%Y-%m-%d",
    "month_day_year" => "%m/%d/%Y",
    "day_month_year" => "%d/%m/%Y"
  }.freeze
  DEFAULT_DATE_FORMAT = "year_month_day"
  DEFAULT_NUMBER_FORMAT = "western"
  NUMBER_FORMATS = {
    "western" => { separator: ".", delimiter: "," },
    "decimal_comma" => { separator: ",", delimiter: "." }
  }.freeze
  FISCAL_YEAR_START_DAYS_BY_MONTH = {
    1 => 31, 2 => 28, 3 => 31, 4 => 30, 5 => 31, 6 => 30,
    7 => 31, 8 => 31, 9 => 30, 10 => 31, 11 => 30, 12 => 31
  }.freeze
  SUPPORTED_DATE_FORMATS = DATE_FORMATS.keys.freeze
  SUPPORTED_FIRST_DAYS_OF_WEEK = (0..6).freeze
  SUPPORTED_FISCAL_YEAR_START_DAYS = (1..31).freeze
  SUPPORTED_FISCAL_YEAR_START_MONTHS = FISCAL_YEAR_START_DAYS_BY_MONTH.keys.freeze
  SUPPORTED_LOCALES = %w[en zh-CN].freeze
  SUPPORTED_NUMBER_FORMATS = NUMBER_FORMATS.keys.freeze

  belongs_to :default_account, class_name: "Account", optional: true
  belongs_to :user

  normalizes :default_currency_code, with: ->(currency) { currency.to_s.strip.upcase }
  normalizes :date_format, with: ->(date_format) { date_format.to_s.strip }
  normalizes :locale, with: ->(locale) { locale.to_s.strip }
  normalizes :number_format, with: ->(number_format) { number_format.to_s.strip }

  validates :default_currency_code, format: { with: /\A[A-Z]{3}\z/ }
  validates :date_format, inclusion: { in: SUPPORTED_DATE_FORMATS }
  validates :first_day_of_week, inclusion: { in: SUPPORTED_FIRST_DAYS_OF_WEEK }
  validates :fiscal_year_start_day, inclusion: { in: SUPPORTED_FISCAL_YEAR_START_DAYS }
  validates :fiscal_year_start_month, inclusion: { in: SUPPORTED_FISCAL_YEAR_START_MONTHS }
  validates :locale, inclusion: { in: SUPPORTED_LOCALES }
  validates :number_format, inclusion: { in: SUPPORTED_NUMBER_FORMATS }
  validates :user_id, uniqueness: true
  validate :default_account_must_be_available
  validate :fiscal_year_start_must_be_valid

  def self.datetime_format_for(date_format)
    "#{DATE_FORMATS.fetch(date_format)} %H:%M"
  end

  def self.number_format_options_for(number_format)
    NUMBER_FORMATS.fetch(number_format).dup
  end

  def as_json(_options = {})
    {
      default_currency_code: default_currency_code,
      default_account_id: default_account&.to_param,
      date_format: date_format,
      first_day_of_week: first_day_of_week,
      fiscal_year_start_month: fiscal_year_start_month,
      fiscal_year_start_day: fiscal_year_start_day,
      locale: locale,
      number_format: number_format
    }
  end

  def datetime_format
    self.class.datetime_format_for(date_format)
  end

  def number_format_options
    self.class.number_format_options_for(number_format)
  end

  private

  def default_account_must_be_available
    return if default_account.blank? || user.blank?
    return if default_account.user_id == user_id && default_account.kept?

    errors.add(:default_account, "is unavailable")
  end

  def fiscal_year_start_must_be_valid
    max_day = FISCAL_YEAR_START_DAYS_BY_MONTH[fiscal_year_start_month]
    return if max_day.present? && fiscal_year_start_day.to_i.between?(1, max_day)

    errors.add(:fiscal_year_start_day, "is invalid for fiscal year start")
  end
end
