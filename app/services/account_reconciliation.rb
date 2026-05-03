class AccountReconciliation
  def build_statement(account:, range:)
    transactions = account_transactions(account)
    period_transactions = transactions.where(transacted_at: range).order(:transacted_at, :id).to_a
    opening_balance_cents = transactions.where("transacted_at < ?", range.begin).sum { |transaction| account_effect(transaction, account) }
    period_effects = period_transactions.map { |transaction| account_effect(transaction, account) }
    inflow_cents = period_effects.select(&:positive?).sum
    outflow_cents = period_effects.select(&:negative?).sum.abs

    Result.new(
      account: account,
      range: range,
      opening_balance_cents: opening_balance_cents,
      closing_balance_cents: opening_balance_cents + inflow_cents - outflow_cents,
      inflow_cents: inflow_cents,
      outflow_cents: outflow_cents,
      transactions: period_transactions
    )
  end

  private

  def account_transactions(account)
    account.user.transactions.kept
      .includes(:account, :destination_account, :transaction_category)
      .where("account_id = :account_id OR destination_account_id = :account_id", account_id: account.id)
  end

  def account_effect(transaction, account)
    case transaction.transaction_kind
    when "balance_adjustment", "income"
      transaction.account_id == account.id ? transaction.source_amount_cents : 0
    when "expense"
      transaction.account_id == account.id ? -transaction.source_amount_cents : 0
    when "transfer"
      transfer_effect(transaction, account)
    else
      0
    end
  end

  def transfer_effect(transaction, account)
    effect = 0
    effect -= transaction.source_amount_cents if transaction.account_id == account.id
    effect += transaction.destination_amount_cents if transaction.destination_account_id == account.id
    effect
  end

  class Result
    attr_reader :account, :range, :opening_balance_cents, :closing_balance_cents,
      :inflow_cents, :outflow_cents, :transactions

    def initialize(account:, range:, opening_balance_cents:, closing_balance_cents:, inflow_cents:, outflow_cents:, transactions:)
      @account = account
      @range = range
      @opening_balance_cents = opening_balance_cents
      @closing_balance_cents = closing_balance_cents
      @inflow_cents = inflow_cents
      @outflow_cents = outflow_cents
      @transactions = transactions
    end
  end
end
