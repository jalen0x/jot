class User < ApplicationRecord
  include Users::Authenticatable, Users::Profile, Users::SoftDelete

  has_many :accounts, dependent: :restrict_with_error
  has_many :transactions, dependent: :restrict_with_error
  has_many :transaction_categories, dependent: :restrict_with_error
  has_many :transaction_tag_groups, dependent: :restrict_with_error
  has_many :transaction_tags, dependent: :restrict_with_error
  has_many :transaction_taggings, dependent: :restrict_with_error
  has_one :user_preference, dependent: :restrict_with_error
  has_many :user_custom_exchange_rates, dependent: :restrict_with_error
  has_many :api_tokens, dependent: :restrict_with_error
end
