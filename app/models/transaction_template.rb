class TransactionTemplate < ApplicationRecord
  include Discard::Model

  has_prefix_id :tmpl

  belongs_to :user
  belongs_to :account
  belongs_to :destination_account, class_name: "Account", optional: true
  belongs_to :transaction_category, optional: true
  has_many :transaction_template_taggings, dependent: :restrict_with_error
  has_many :transaction_tags, through: :transaction_template_taggings

  enum :template_kind, {
    normal: 1,
    scheduled: 2
  }

  enum :transaction_kind, {
    balance_adjustment: 1,
    income: 2,
    expense: 3,
    transfer: 4
  }

  enum :schedule_frequency, {
    disabled: 0,
    weekly: 1,
    monthly: 2,
    daily: 3,
    yearly: 4
  }

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :comment, with: ->(comment) { comment.to_s.strip }
  normalizes :schedule_rule, with: ->(rule) { rule.to_s.strip }

  validates :name, presence: true
  validates :display_order, numericality: { only_integer: true }
  validates :source_amount_cents, numericality: { only_integer: true }
  validates :destination_amount_cents, numericality: { only_integer: true }
  validates :scheduled_at_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1439 }
  validates :timezone_utc_offset_minutes, numericality: { only_integer: true, greater_than_or_equal_to: -720, less_than_or_equal_to: 840 }
  validates :transaction_category, presence: true, unless: :balance_adjustment?
  validates :destination_account, presence: true, if: :transfer?
  validate :destination_account_differs_from_source

  def as_json(_options = {})
    {
      id: to_param,
      template_kind: template_kind,
      transaction_kind: transaction_kind,
      name: name,
      account_id: account.to_param,
      destination_account_id: destination_account&.to_param,
      transaction_category_id: transaction_category&.to_param,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      hide_amount: hide_amount,
      comment: comment,
      schedule_frequency: schedule_frequency,
      schedule_rule: schedule_rule,
      schedule_start_on: schedule_start_on&.iso8601,
      schedule_end_on: schedule_end_on&.iso8601,
      scheduled_at_minutes: scheduled_at_minutes,
      timezone_utc_offset_minutes: timezone_utc_offset_minutes,
      last_generated_on: last_generated_on&.iso8601,
      display_order: display_order,
      hidden: hidden,
      transaction_tag_ids: transaction_tags.map(&:to_param)
    }
  end

  private

  def destination_account_differs_from_source
    return if destination_account.blank?
    return if account != destination_account

    errors.add(:destination_account, "must differ from source account")
  end
end
