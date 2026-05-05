class LedgerQuery
  class InvalidAmountFilter < StandardError; end
  class InvalidDateFilter < StandardError; end

  def list_transactions(user:, filters: {})
    filters = filters.to_h.deep_symbolize_keys
    scope = user.transactions.kept.includes(:account, :destination_account, :transaction_category, :transaction_tags)
    scope = scope.where(transaction_kind: filters[:transaction_kind]) if filters[:transaction_kind].present?
    scope = apply_id_filter(scope, column: :account_id, model: Account, single: filters[:account_id], multiple: filters[:account_ids])
    scope = apply_id_filter(scope, column: :transaction_category_id, model: TransactionCategory, single: filters[:transaction_category_id], multiple: filters[:transaction_category_ids])
    scope = apply_tag_filters(scope, user: user, tag_id: filters[:tag_id], tag_filter: filters[:tag_filter])
    scope = apply_keyword_filter(scope, filters[:keyword])
    scope = apply_amount_filters(scope, minimum: filters[:minimum_amount_cents], maximum: filters[:maximum_amount_cents])
    scope = apply_date_filters(scope, start_date: filters[:start_date], end_date: filters[:end_date])
    scope.order(transacted_at: :desc, id: :desc).distinct
  end

  private

  def apply_id_filter(scope, column:, model:, single:, multiple:)
    ids = decoded_ids(model, [ single, multiple ])
    return scope if ids.empty?

    scope.where(column => ids)
  end

  def decoded_ids(model, values)
    Array(values).flatten.reject(&:blank?).map { |value| decoded_id(model, value) }.uniq
  end

  def apply_tag_filters(scope, user:, tag_id:, tag_filter:)
    scope = include_any_tags(scope, [ decoded_id(TransactionTag, tag_id) ]) if tag_id.present?
    return scope unless tag_filter.is_a?(Hash)

    scope = scope.where.missing(:transaction_taggings) if true?(tag_filter[:without_tags])
    scope = include_any_tags(scope, tag_ids(tag_filter[:include_any_ids]))
    scope = include_all_tags(scope, user, tag_ids(tag_filter[:include_all_ids]))
    scope = exclude_any_tags(scope, user, tag_ids(tag_filter[:exclude_any_ids]))
    exclude_all_tags(scope, user, tag_ids(tag_filter[:exclude_all_ids]))
  end

  def include_any_tags(scope, tag_ids)
    return scope if tag_ids.empty?

    scope.joins(:transaction_taggings).where(transaction_taggings: { transaction_tag_id: tag_ids })
  end

  def include_all_tags(scope, user, tag_ids)
    return scope if tag_ids.empty?

    scope.where(id: transaction_ids_with_all_tags(user, tag_ids))
  end

  def exclude_any_tags(scope, user, tag_ids)
    return scope if tag_ids.empty?

    scope.where.not(id: transaction_ids_with_any_tags(user, tag_ids))
  end

  def exclude_all_tags(scope, user, tag_ids)
    return scope if tag_ids.empty?

    scope.where.not(id: transaction_ids_with_all_tags(user, tag_ids))
  end

  def transaction_ids_with_any_tags(user, tag_ids)
    TransactionTagging.where(user: user, transaction_tag_id: tag_ids).select(:transaction_id)
  end

  def transaction_ids_with_all_tags(user, tag_ids)
    transaction_ids_with_any_tags(user, tag_ids).group(:transaction_id).having("COUNT(DISTINCT transaction_tag_id) = ?", tag_ids.size)
  end

  def tag_ids(values)
    Array(values).reject(&:blank?).map { |value| decoded_id(TransactionTag, value) }.uniq
  end

  def true?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def apply_keyword_filter(scope, keyword)
    keyword = keyword.to_s.strip
    return scope if keyword.blank?

    scope.where("transactions.comment ILIKE ?", "%#{Transaction.sanitize_sql_like(keyword)}%")
  end

  def apply_amount_filters(scope, minimum:, maximum:)
    minimum = amount_cents(minimum)
    maximum = amount_cents(maximum)
    scope = scope.where("transactions.source_amount_cents >= ?", minimum) if minimum
    scope = scope.where("transactions.source_amount_cents <= ?", maximum) if maximum
    scope
  end

  def amount_cents(value)
    return if value.blank?

    Integer(value, 10)
  rescue ArgumentError
    raise InvalidAmountFilter, "Amount filters must be integer cents"
  end

  def apply_date_filters(scope, start_date:, end_date:)
    start_date = date_filter(start_date)
    end_date = date_filter(end_date)
    scope = scope.where("transactions.transacted_at >= ?", start_date.beginning_of_day) if start_date
    scope = scope.where("transactions.transacted_at <= ?", end_date.end_of_day) if end_date
    scope
  end

  def date_filter(value)
    return if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    raise InvalidDateFilter, "Start date and end date must be valid ISO 8601 dates"
  end

  def decoded_id(model, value)
    model.decode_prefix_id(value) || value
  end
end
