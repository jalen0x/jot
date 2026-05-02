class Transaction < ApplicationRecord
  include Discard::Model

  has_prefix_id :txn

  belongs_to :user
  belongs_to :account
  belongs_to :destination_account, class_name: "Account", optional: true

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
  validates :destination_account, presence: true, if: :transfer?
end
