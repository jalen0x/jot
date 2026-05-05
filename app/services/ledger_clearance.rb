class LedgerClearance
  def clear_transactions(user:)
    now = Time.current
    purge_transaction_pictures(user)

    ActiveRecord::Base.transaction do
      clear_transaction_rows(user: user, now: now)
    end
  end

  def clear_account_transactions(user:, account:)
    errors = account_clearance_errors(user, account)
    return Result.new(cleared: false, errors: errors) if errors.any?

    result = TransactionBatchDeleter.new.delete_transactions(transactions: account_transactions(user, account))
    return Result.new(cleared: true) if result.deleted?

    Result.new(cleared: false, errors: result.transaction.errors.full_messages)
  end

  def clear_all_data(user:)
    now = Time.current
    purge_transaction_pictures(user)

    ActiveRecord::Base.transaction do
      clear_transaction_rows(user: user, now: now)
      TransactionTemplateTagging.where(user: user).delete_all
      user.insight_explorers.kept.update_all(discarded_at: now, updated_at: now)
      user.transaction_templates.kept.update_all(discarded_at: now, updated_at: now)
      user.transaction_categories.kept.update_all(discarded_at: now, updated_at: now)
      user.transaction_tags.kept.update_all(discarded_at: now, updated_at: now)
      user.transaction_tag_groups.kept.update_all(discarded_at: now, updated_at: now)
      user.user_custom_exchange_rates.kept.update_all(discarded_at: now, updated_at: now)
      user.accounts.kept.update_all(discarded_at: now, updated_at: now)
    end
  end

  private

  def clear_transaction_rows(user:, now:)
    TransactionTagging.where(user: user).delete_all
    user.transactions.kept.update_all(discarded_at: now, updated_at: now)
    user.accounts.kept.update_all(balance_cents: 0, updated_at: now)
  end

  def purge_transaction_pictures(user)
    user.transactions.kept.with_attached_pictures.find_each do |transaction|
      transaction.pictures.purge if transaction.pictures.attached?
    end
  end

  def account_clearance_errors(user, account)
    errors = []
    errors << "Account is unavailable" if account.user_id != user.id
    errors << "Cannot clear transactions for a hidden account" if account.hidden?
    errors << "Cannot clear transactions for a parent account" if account.multi_sub_accounts?
    errors
  end

  def account_transactions(user, account)
    user.transactions.kept
      .where(account: account)
      .or(user.transactions.kept.where(destination_account: account))
      .order(:id)
      .to_a
  end

  class Result
    attr_reader :errors

    def initialize(cleared:, errors: [])
      @cleared = cleared
      @errors = errors
    end

    def cleared? = @cleared
  end
end
