class TransactionRecorder
  def record_transaction(user:, attributes:, tag_ids:)
    transaction = user.transactions.build(transaction_attributes(attributes))
    tags = assign_owned_records(user, transaction, attributes, tag_ids)
    validate_business_rules(transaction)

    return Result.new(recorded: false, transaction: transaction) if transaction.errors.any? || !transaction.valid?

    ActiveRecord::Base.transaction do
      transaction.save!
      tags.each do |tag|
        transaction.transaction_taggings.create!(user: user, transaction_tag: tag)
      end
      update_balances(transaction)
    end

    transaction.association(:transaction_tags).target = tags
    Result.new(recorded: true, transaction: transaction)
  end

  private

  def transaction_attributes(attributes)
    attributes = attributes.to_h.symbolize_keys

    {
      transaction_kind: attributes[:transaction_kind],
      transacted_at: attributes[:transacted_at],
      timezone_utc_offset_minutes: attributes[:timezone_utc_offset_minutes].to_i,
      source_amount_cents: attributes[:source_amount_cents].to_i,
      destination_amount_cents: attributes[:destination_amount_cents].to_i,
      hide_amount: ActiveModel::Type::Boolean.new.cast(attributes[:hide_amount]),
      comment: attributes[:comment]
    }
  end

  def assign_owned_records(user, transaction, attributes, tag_ids)
    attributes = attributes.to_h.symbolize_keys
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

  def update_balances(transaction)
    case transaction.transaction_kind
    when "income"
      transaction.account.update!(balance_cents: transaction.account.balance_cents + transaction.source_amount_cents)
    when "expense"
      transaction.account.update!(balance_cents: transaction.account.balance_cents - transaction.source_amount_cents)
    when "transfer"
      transaction.account.update!(balance_cents: transaction.account.balance_cents - transaction.source_amount_cents)
      transaction.destination_account.update!(balance_cents: transaction.destination_account.balance_cents + transaction.destination_amount_cents)
    end
  end

  class Result
    attr_reader :transaction

    def initialize(recorded:, transaction:)
      @recorded = recorded
      @transaction = transaction
    end

    def recorded? = @recorded
  end
end
