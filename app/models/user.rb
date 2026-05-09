class User < ApplicationRecord
  include Users::Authenticatable, Users::Profile, Users::SoftDelete

  has_many :accounts, dependent: :restrict_with_error
  has_many :transactions, dependent: :restrict_with_error
  has_many :transaction_categories, dependent: :restrict_with_error
  has_many :transaction_tag_groups, dependent: :restrict_with_error
  has_many :transaction_tags, dependent: :restrict_with_error
  has_many :transaction_taggings, dependent: :restrict_with_error
  has_many :transaction_templates, dependent: :restrict_with_error
  has_many :transaction_template_taggings, dependent: :restrict_with_error
  has_many :import_batches, dependent: :restrict_with_error
  has_many :insight_explorers, dependent: :restrict_with_error
  has_many :receipt_recognitions, dependent: :restrict_with_error
  has_one :user_preference, dependent: :restrict_with_error
  has_many :user_custom_exchange_rates, dependent: :restrict_with_error
  has_many :api_tokens, dependent: :restrict_with_error
  has_many :two_factor_recovery_codes, dependent: :destroy
  has_one :two_factor_authentication, dependent: :destroy
  has_one :application_lock, dependent: :destroy

  def two_factor_enabled? = two_factor_authentication.present?

  def application_lock_enabled?
    ApplicationLock.exists?(user_id: id)
  end
end
