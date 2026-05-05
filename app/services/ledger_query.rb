class LedgerQuery
  def list_transactions(user:, filters: {})
    filters = filters.to_h.deep_symbolize_keys
    scope = user.transactions.kept.includes(:account, :destination_account, :transaction_category, :transaction_tags)
    scope = scope.where(transaction_kind: filters[:transaction_kind]) if filters[:transaction_kind].present?
    scope = scope.where(account_id: decoded_id(Account, filters[:account_id])) if filters[:account_id].present?
    scope = scope.where(transaction_category_id: decoded_id(TransactionCategory, filters[:transaction_category_id])) if filters[:transaction_category_id].present?
    scope = apply_tag_filters(scope, user: user, tag_id: filters[:tag_id], tag_filter: filters[:tag_filter])
    scope.order(transacted_at: :desc, id: :desc).distinct
  end

  private

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

  def decoded_id(model, value)
    model.decode_prefix_id(value) || value
  end
end
