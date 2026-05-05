class AccountDiscarder
  def discard_account(account:)
    ActiveRecord::Base.transaction do
      now = Time.current
      account.user.accounts.kept
        .where(parent_account: account)
        .update_all(discarded_at: now, updated_at: now)
      account.discard!
    end

    nil
  end
end
