class Account < ApplicationRecord
  include Discard::Model

  has_prefix_id :acct

  belongs_to :user
  belongs_to :parent_account, class_name: "Account", optional: true
  has_many :sub_accounts, class_name: "Account", foreign_key: :parent_account_id, dependent: :restrict_with_error, inverse_of: :parent_account
  has_many :transactions, dependent: :restrict_with_error

  enum :account_category, {
    cash: 1,
    checking_account: 2,
    credit_card: 3,
    virtual: 4,
    debt: 5,
    receivables: 6,
    investment: 7,
    savings_account: 8,
    certificate_of_deposit: 9
  }

  enum :account_structure, {
    single_account: 1,
    multi_sub_accounts: 2
  }

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :color_hex, with: ->(color) { color.to_s.delete_prefix("#").upcase }
  normalizes :currency_code, with: ->(currency) { currency.to_s.upcase }
  normalizes :comment, with: ->(comment) { comment.to_s.strip }

  validates :name, presence: true
  validates :icon_key, numericality: { only_integer: true, greater_than: 0 }
  validates :color_hex, format: { with: /\A\h{6}\z/ }
  validates :currency_code, format: { with: /\A[A-Z]{3}\z/ }

  def as_json(_options = {})
    {
      id: to_param,
      name: name,
      account_category: account_category,
      account_structure: account_structure,
      currency_code: currency_code,
      balance_cents: balance_cents,
      parent_account_id: parent_account&.to_param,
      hidden: hidden
    }
  end
end
