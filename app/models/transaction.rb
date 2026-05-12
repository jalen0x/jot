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
  validates :geo_latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :geo_longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :transaction_category, presence: true, unless: :balance_adjustment?
  validates :transaction_category, absence: true, if: :balance_adjustment?
  validates :destination_account, presence: true, if: :transfer?
  validate :geo_location_pair

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
      geo_location: geo_location_json,
      transaction_tag_ids: transaction_tags.map(&:to_param)
    }
  end

  def source_balance_delta
    case transaction_kind
    when "balance_adjustment", "income" then  source_amount_cents
    when "expense", "transfer"          then -source_amount_cents
    end
  end

  def destination_balance_delta
    transfer? ? destination_amount_cents : 0
  end

  def balance_effects
    effects = [ [ account, source_balance_delta ] ]
    effects << [ destination_account, destination_balance_delta ] if transfer?
    effects
  end

  private

  def geo_location_pair
    if geo_latitude.present? && geo_longitude.blank?
      errors.add(:geo_longitude, "can't be blank when latitude is present")
    elsif geo_longitude.present? && geo_latitude.blank?
      errors.add(:geo_latitude, "can't be blank when longitude is present")
    end
  end

  def geo_location_json
    return if geo_latitude.blank? && geo_longitude.blank?

    {
      latitude: geo_latitude.to_s,
      longitude: geo_longitude.to_s
    }
  end
end
