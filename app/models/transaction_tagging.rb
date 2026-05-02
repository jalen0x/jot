class TransactionTagging < ApplicationRecord
  belongs_to :user
  belongs_to :ledger_transaction, class_name: "Transaction", foreign_key: :transaction_id, inverse_of: :transaction_taggings
  belongs_to :transaction_tag
end
