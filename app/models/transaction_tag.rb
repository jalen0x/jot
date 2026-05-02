class TransactionTag < ApplicationRecord
  include Discard::Model

  has_prefix_id :tag

  belongs_to :user
  belongs_to :transaction_tag_group, optional: true
  has_many :transaction_taggings, dependent: :restrict_with_error
  has_many :transactions, through: :transaction_taggings, source: :ledger_transaction

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true
end
