class Transaction < ApplicationRecord
  include Discard::Model

  has_prefix_id :txn

  belongs_to :user
  belongs_to :account
  belongs_to :destination_account, class_name: "Account", optional: true
  belongs_to :transaction_category, optional: true
  has_many :transaction_taggings, foreign_key: :transaction_id, dependent: :restrict_with_error, inverse_of: :ledger_transaction
  has_many :transaction_tags, through: :transaction_taggings
  has_many_attached :pictures

  enum :transaction_kind, {
    balance_adjustment: 1,
    income: 2,
    expense: 3,
    transfer: 4
  }

  normalizes :comment, with: ->(comment) { comment.to_s.strip }

  validates :transacted_at, presence: true
  validates :source_amount_cents, numericality: { only_integer: true }
  validates :destination_amount_cents, numericality: { only_integer: true }
  validates :transaction_category, presence: true, unless: :balance_adjustment?
  validates :transaction_category, absence: true, if: :balance_adjustment?
  validates :destination_account, presence: true, if: :transfer?

  def as_json(_options = {})
    {
      id: to_param,
      transaction_kind: transaction_kind,
      account_id: account.to_param,
      destination_account_id: destination_account&.to_param,
      transaction_category_id: transaction_category&.to_param,
      transacted_at: transacted_at.iso8601,
      timezone_utc_offset_minutes: timezone_utc_offset_minutes,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      hide_amount: hide_amount,
      comment: comment,
      transaction_tag_ids: transaction_tags.map(&:to_param)
    }
  end
end
