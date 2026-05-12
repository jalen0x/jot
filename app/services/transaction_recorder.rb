class TransactionRecorder
  def record_transaction(user:, attributes:, tag_ids:, picture_files: [], enforce_transaction_edit_scope: true)
    transaction = user.transactions.build(transaction_attributes(attributes))
    tags = assign_owned_records(user, transaction, attributes, tag_ids)
    validate_business_rules(transaction)
    validate_transaction_edit_scope(transaction) if enforce_transaction_edit_scope

    return Result.new(recorded: false, transaction: transaction) if transaction.errors.any? || !transaction.valid?

    ActiveRecord::Base.transaction do
      transaction.save!
      tags.each do |tag|
        transaction.transaction_taggings.create!(user: user, transaction_tag: tag)
      end
      transaction.pictures.attach(picture_attachables(picture_files))
      AccountBalanceLedger.new.apply(transaction)
    end

    transaction.association(:transaction_tags).target = tags
    Result.new(recorded: true, transaction: transaction)
  end

  private

  def transaction_attributes(attributes)
    attributes = attributes.to_h.symbolize_keys

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

  def validate_transaction_edit_scope(transaction)
    return if transaction.transacted_at.blank?
    return if TransactionEditScope.new.editable?(transaction: transaction)

    transaction.errors.add(:base, TransactionEditScope::NOT_EDITABLE_MESSAGE)
  end

  def picture_attachables(picture_files)
    Array(picture_files).reject(&:blank?).map do |file|
      next file unless file.respond_to?(:tempfile)

      {
        io: file.tempfile,
        filename: file.original_filename,
        content_type: file.content_type,
        identify: false
      }
    end
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

  class Result
    attr_reader :transaction

    def initialize(recorded:, transaction:)
      @recorded = recorded
      @transaction = transaction
    end

    def recorded? = @recorded
  end
end
