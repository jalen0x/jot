class TransactionTemplateTagging < ApplicationRecord
  belongs_to :user
  belongs_to :transaction_template
  belongs_to :transaction_tag
end
