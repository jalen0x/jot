class LedgerQuery
  def list_transactions(user:, filters: {})
    filters = filters.to_h.symbolize_keys
    scope = user.transactions.kept.includes(:account, :destination_account, :transaction_category, :transaction_tags)
    scope = scope.where(transaction_kind: filters[:transaction_kind]) if filters[:transaction_kind].present?
    scope = scope.where(account_id: decoded_id(Account, filters[:account_id])) if filters[:account_id].present?
    scope = scope.where(transaction_category_id: decoded_id(TransactionCategory, filters[:transaction_category_id])) if filters[:transaction_category_id].present?
    scope = scope.joins(:transaction_taggings).where(transaction_taggings: { transaction_tag_id: decoded_id(TransactionTag, filters[:tag_id]) }) if filters[:tag_id].present?
    scope.order(transacted_at: :desc, id: :desc).distinct
  end

  private

  def decoded_id(model, value)
    model.decode_prefix_id(value) || value
  end
end
