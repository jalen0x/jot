class UserPreference < ApplicationRecord
  AMOUNT_COLORS = %w[success danger warning neutral].freeze
  DATE_FORMATS = {
    "year_month_day" => "%Y-%m-%d",
    "month_day_year" => "%m/%d/%Y",
    "day_month_year" => "%d/%m/%Y"
  }.freeze
  CURRENCY_DISPLAY_FORMATS = %w[code_after_amount code_before_amount none].freeze
  COORDINATE_DISPLAY_FORMATS = %w[
    latitude_longitude_decimal_degrees
    longitude_latitude_decimal_degrees
    latitude_longitude_decimal_minutes
    longitude_latitude_decimal_minutes
    latitude_longitude_degrees_minutes_seconds
    longitude_latitude_degrees_minutes_seconds
  ].freeze
  TIME_FORMATS = {
    "twenty_four_hour" => "%H:%M",
    "twelve_hour" => "%I:%M %p"
  }.freeze
  DEFAULT_DATE_FORMAT = "year_month_day"
  DEFAULT_NUMBER_FORMAT = "western"
  DEFAULT_CURRENCY_DISPLAY_FORMAT = "code_after_amount"
  DEFAULT_COORDINATE_DISPLAY_FORMAT = "latitude_longitude_decimal_degrees"
  DEFAULT_EXPENSE_AMOUNT_COLOR = "danger"
  DEFAULT_INCOME_AMOUNT_COLOR = "success"
  DEFAULT_TIME_FORMAT = "twenty_four_hour"
  NUMBER_FORMATS = {
    "western" => { separator: ".", delimiter: "," },
    "decimal_comma" => { separator: ",", delimiter: "." }
  }.freeze
  FISCAL_YEAR_START_DAYS_BY_MONTH = {
    1 => 31, 2 => 28, 3 => 31, 4 => 30, 5 => 31, 6 => 30,
    7 => 31, 8 => 31, 9 => 30, 10 => 31, 11 => 30, 12 => 31
  }.freeze
  FISCAL_YEAR_FORMATS = %w[
    start_year_end_year
    start_year_end_short_year
    start_short_year_end_short_year
    end_year
    end_short_year
  ].freeze
  SUPPORTED_AMOUNT_COLORS = AMOUNT_COLORS
  SUPPORTED_DATE_FORMATS = DATE_FORMATS.keys.freeze
  SUPPORTED_CURRENCY_DISPLAY_FORMATS = CURRENCY_DISPLAY_FORMATS
  SUPPORTED_COORDINATE_DISPLAY_FORMATS = COORDINATE_DISPLAY_FORMATS
  SUPPORTED_FIRST_DAYS_OF_WEEK = (0..6).freeze
  SUPPORTED_FISCAL_YEAR_FORMATS = FISCAL_YEAR_FORMATS
  SUPPORTED_FISCAL_YEAR_START_DAYS = (1..31).freeze
  SUPPORTED_FISCAL_YEAR_START_MONTHS = FISCAL_YEAR_START_DAYS_BY_MONTH.keys.freeze
  SUPPORTED_LOCALES = %w[en zh-CN].freeze
  SUPPORTED_NUMBER_FORMATS = NUMBER_FORMATS.keys.freeze
  SUPPORTED_TIME_FORMATS = TIME_FORMATS.keys.freeze

  belongs_to :default_account, class_name: "Account", optional: true
  belongs_to :user

  normalizes :coordinate_display_format, with: ->(format) { format.to_s.strip }
  normalizes :default_currency_code, with: ->(currency) { currency.to_s.strip.upcase }
  normalizes :currency_display_format, with: ->(format) { format.to_s.strip }
  normalizes :date_format, with: ->(date_format) { date_format.to_s.strip }
  normalizes :expense_amount_color, with: ->(color) { color.to_s.strip }
  normalizes :fiscal_year_format, with: ->(fiscal_year_format) { fiscal_year_format.to_s.strip }
  normalizes :income_amount_color, with: ->(color) { color.to_s.strip }
  normalizes :locale, with: ->(locale) { locale.to_s.strip }
  normalizes :number_format, with: ->(number_format) { number_format.to_s.strip }
  normalizes :time_format, with: ->(time_format) { time_format.to_s.strip }

  validates :default_currency_code, format: { with: /\A[A-Z]{3}\z/ }
  validates :coordinate_display_format, inclusion: { in: SUPPORTED_COORDINATE_DISPLAY_FORMATS }
  validates :currency_display_format, inclusion: { in: SUPPORTED_CURRENCY_DISPLAY_FORMATS }
  validates :date_format, inclusion: { in: SUPPORTED_DATE_FORMATS }
  validates :expense_amount_color, inclusion: { in: SUPPORTED_AMOUNT_COLORS }
  validates :first_day_of_week, inclusion: { in: SUPPORTED_FIRST_DAYS_OF_WEEK }
  validates :fiscal_year_start_day, inclusion: { in: SUPPORTED_FISCAL_YEAR_START_DAYS }
  validates :fiscal_year_start_month, inclusion: { in: SUPPORTED_FISCAL_YEAR_START_MONTHS }
  validates :fiscal_year_format, inclusion: { in: SUPPORTED_FISCAL_YEAR_FORMATS }
  validates :income_amount_color, inclusion: { in: SUPPORTED_AMOUNT_COLORS }
  validates :locale, inclusion: { in: SUPPORTED_LOCALES }
  validates :number_format, inclusion: { in: SUPPORTED_NUMBER_FORMATS }
  validates :time_format, inclusion: { in: SUPPORTED_TIME_FORMATS }
  validates :user_id, uniqueness: true
  validate :default_account_must_be_available
  validate :fiscal_year_start_must_be_valid

  def self.datetime_format_for(date_format, time_format = DEFAULT_TIME_FORMAT)
    "#{DATE_FORMATS.fetch(date_format)} #{TIME_FORMATS.fetch(time_format)}"
  end

  def self.number_format_options_for(number_format)
    NUMBER_FORMATS.fetch(number_format).dup
  end

  def as_json(_options = {})
    {
      default_currency_code: default_currency_code,
      default_account_id: default_account&.to_param,
      coordinate_display_format: coordinate_display_format,
      currency_display_format: currency_display_format,
      date_format: date_format,
      expense_amount_color: expense_amount_color,
      first_day_of_week: first_day_of_week,
      fiscal_year_start_month: fiscal_year_start_month,
      fiscal_year_start_day: fiscal_year_start_day,
      fiscal_year_format: fiscal_year_format,
      income_amount_color: income_amount_color,
      locale: locale,
      number_format: number_format,
      time_format: time_format
    }
  end

  def datetime_format
    self.class.datetime_format_for(date_format, time_format)
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
