class TransactionCategory < ApplicationRecord
  include Discard::Model

  has_prefix_id :cat

  belongs_to :user
  belongs_to :parent_category, class_name: "TransactionCategory", optional: true
  has_many :sub_categories, class_name: "TransactionCategory", foreign_key: :parent_category_id, dependent: :restrict_with_error, inverse_of: :parent_category
  has_many :transactions, dependent: :restrict_with_error

  enum :category_type, {
    income: 1,
    expense: 2,
    transfer: 3
  }

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :color_hex, with: ->(color) { color.to_s.delete_prefix("#").upcase }
  normalizes :comment, with: ->(comment) { comment.to_s.strip }

  validates :name, presence: true
  validates :icon_key, numericality: { only_integer: true, greater_than: 0 }
  validates :color_hex, format: { with: /\A\h{6}\z/ }

  def as_json(_options = {})
    {
      id: to_param,
      name: name,
      category_type: category_type,
      parent_category_id: parent_category&.to_param,
      display_order: display_order,
      icon_key: icon_key,
      color_hex: color_hex,
      hidden: hidden,
      comment: comment
    }
  end
end
