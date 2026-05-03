class LedgerClearance
  def clear_transactions(user:)
    now = Time.current

    ActiveRecord::Base.transaction do
      TransactionTagging.where(user: user).delete_all
      user.transactions.kept.update_all(discarded_at: now, updated_at: now)
      user.accounts.kept.update_all(balance_cents: 0, updated_at: now)
    end
  end

  def clear_all_data(user:)
    now = Time.current

    ActiveRecord::Base.transaction do
      clear_transactions(user: user)
      user.transaction_categories.kept.update_all(discarded_at: now, updated_at: now)
      user.transaction_tags.kept.update_all(discarded_at: now, updated_at: now)
      user.transaction_tag_groups.kept.update_all(discarded_at: now, updated_at: now)
      user.user_custom_exchange_rates.kept.update_all(discarded_at: now, updated_at: now)
      user.accounts.kept.update_all(discarded_at: now, updated_at: now)
    end
  end
end
