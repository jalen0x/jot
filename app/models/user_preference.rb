class UserPreference < ApplicationRecord
  belongs_to :user

  normalizes :default_currency_code, with: ->(currency) { currency.to_s.strip.upcase }

  validates :default_currency_code, format: { with: /\A[A-Z]{3}\z/ }
  validates :user_id, uniqueness: true

  def as_json(_options = {})
    {
      default_currency_code: default_currency_code
    }
  end
end
