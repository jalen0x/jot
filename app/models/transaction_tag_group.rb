class TransactionTagGroup < ApplicationRecord
  include Discard::Model

  has_prefix_id :taggrp

  belongs_to :user
  has_many :transaction_tags, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true

  def as_json(_options = {})
    {
      id: to_param,
      name: name,
      display_order: display_order
    }
  end
end
