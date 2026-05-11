class TransactionUpdater
  def update_transaction(transaction:, attributes:, tag_ids:)
    unless TransactionEditScope.new.editable?(transaction: transaction)
      transaction.errors.add(:base, TransactionEditScope::NOT_EDITABLE_MESSAGE)
      return Result.new(updated: false, transaction: transaction)
    end

    original_balance = balance_snapshot(transaction)
    attributes = attributes.to_h.symbolize_keys
    transaction.assign_attributes(transaction_attributes(attributes))
    tags = assign_owned_records(transaction.user, transaction, attributes, tag_ids)
    validate_business_rules(transaction)

    return Result.new(updated: false, transaction: transaction) if transaction.errors.any? || !transaction.valid?

    ActiveRecord::Base.transaction do
      reverse_balances(original_balance)
      transaction.save!
      TransactionTagging.where(ledger_transaction: transaction).delete_all
      tags.each do |tag|
        transaction.transaction_taggings.create!(user: transaction.user, transaction_tag: tag)
      end
      update_balances(transaction)
    end

    transaction.association(:transaction_tags).target = tags
    Result.new(updated: true, transaction: transaction)
  end

  private

  def transaction_attributes(attributes)
    attrs = {
      transaction_kind: attributes[:transaction_kind],
      transacted_at: attributes[:transacted_at],
      timezone_utc_offset_minutes: attributes[:timezone_utc_offset_minutes].to_i,
      source_amount_cents: attributes[:source_amount_cents].to_i,
      destination_amount_cents: attributes[:destination_amount_cents].to_i,
      comment: attributes[:comment],
      geo_latitude: coordinate_value(attributes, :latitude, :geo_latitude),
      geo_longitude: coordinate_value(attributes, :longitude, :geo_longitude)
    }
    attrs[:hide_amount] = ActiveModel::Type::Boolean.new.cast(attributes[:hide_amount]) unless attributes[:hide_amount].nil?
    attrs
  end

  def coordinate_value(attributes, nested_key, direct_key)
    direct_value = attributes[direct_key]
    return direct_value if direct_value.present?

    geo_location = attributes[:geo_location]
    geo_location = geo_location.to_h.symbolize_keys if geo_location.respond_to?(:to_h)
    geo_location[nested_key] if geo_location.present?
  end

  def assign_owned_records(user, transaction, attributes, tag_ids)
    transaction.account = find_owned(user.accounts.kept, attributes[:account_id], transaction, :account)
    transaction.destination_account = find_owned(user.accounts.kept, attributes[:destination_account_id], transaction, :destination_account)
    transaction.transaction_category = find_owned(user.transaction_categories.kept, attributes[:transaction_category_id], transaction, :transaction_category)
    find_tags(user, tag_ids, transaction)
  end

  def find_owned(scope, id, transaction, field)
    return if id.blank?

    scope.find(decoded_id(scope, id))
  rescue ActiveRecord::RecordNotFound
    transaction.errors.add(field, "is unavailable")
    nil
  end

  def find_tags(user, tag_ids, transaction)
    requested_ids = Array(tag_ids).reject(&:blank?).map(&:to_s).uniq
    return [] if requested_ids.empty?

    tags = requested_ids.filter_map do |id|
      user.transaction_tags.kept.find(decoded_id(user.transaction_tags.kept, id))
    rescue ActiveRecord::RecordNotFound
      nil
    end
    transaction.errors.add(:transaction_tags, "include unavailable tags") if tags.size != requested_ids.size
    tags
  end

  def decoded_id(scope, id)
    scope.klass.decode_prefix_id(id) || id
  end

  def validate_business_rules(transaction)
    validate_category_type(transaction)
    validate_transfer(transaction) if transaction.transfer?
  end

  def validate_category_type(transaction)
    return if transaction.balance_adjustment? || transaction.transaction_category.blank?
    return if transaction.transaction_category.category_type == transaction.transaction_kind

    transaction.errors.add(:transaction_category, "does not match transaction type")
  end

  def validate_transfer(transaction)
    if transaction.destination_account.blank?
      transaction.errors.add(:destination_account, "can't be blank")
      return
    end

    transaction.errors.add(:destination_account, "must differ from source account") if transaction.account == transaction.destination_account

    if transaction.source_amount_cents.negative? || transaction.destination_amount_cents.negative?
      transaction.errors.add(:source_amount_cents, "must be greater than or equal to 0 for transfers")
    end

    if transaction.account&.currency_code == transaction.destination_account.currency_code && transaction.source_amount_cents != transaction.destination_amount_cents
      transaction.errors.add(:destination_amount_cents, "must equal source amount for same-currency transfers")
    end
  end

  def balance_snapshot(transaction)
    {
      transaction_kind: transaction.transaction_kind,
      account: transaction.account,
      destination_account: transaction.destination_account,
      source_amount_cents: transaction.source_amount_cents,
      destination_amount_cents: transaction.destination_amount_cents
    }
  end

  def reverse_balances(snapshot)
    case snapshot.fetch(:transaction_kind)
    when "balance_adjustment"
      adjust_balance(snapshot.fetch(:account), -snapshot.fetch(:source_amount_cents))
    when "income"
      adjust_balance(snapshot.fetch(:account), -snapshot.fetch(:source_amount_cents))
    when "expense"
      adjust_balance(snapshot.fetch(:account), snapshot.fetch(:source_amount_cents))
    when "transfer"
      adjust_balance(snapshot.fetch(:account), snapshot.fetch(:source_amount_cents))
      adjust_balance(snapshot.fetch(:destination_account), -snapshot.fetch(:destination_amount_cents))
    end
  end

  def update_balances(transaction)
    case transaction.transaction_kind
    when "income"
      adjust_balance(transaction.account, transaction.source_amount_cents)
    when "expense"
      adjust_balance(transaction.account, -transaction.source_amount_cents)
    when "transfer"
      adjust_balance(transaction.account, -transaction.source_amount_cents)
      adjust_balance(transaction.destination_account, transaction.destination_amount_cents)
    end
  end

  def adjust_balance(account, delta_cents)
    account.update!(balance_cents: account.reload.balance_cents + delta_cents)
  end

  class Result
    attr_reader :transaction

    def initialize(updated:, transaction:)
      @updated = updated
      @transaction = transaction
    end

    def updated? = @updated
  end
end
