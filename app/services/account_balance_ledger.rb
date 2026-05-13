class AccountBalanceLedger
  def apply(transaction)
    transaction.balance_effects.each { |account, delta| adjust(account, delta) }
  end

  def reverse(transaction)
    transaction.balance_effects.each { |account, delta| adjust(account, -delta) }
  end

  def adjust(account, delta_cents)
    return if delta_cents.zero?

    Account.update_counters(account.id, balance_cents: delta_cents, touch: true)
  end
end
