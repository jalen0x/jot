class DashboardSummary
  def summarize(user:)
    accounts = user.accounts.kept
    transactions = user.transactions.kept

    Result.new(
      total_balance_cents: accounts.sum(:balance_cents),
      account_count: accounts.count,
      transaction_count: transactions.count,
      recent_transactions: transactions.includes(:account, :transaction_category).order(transacted_at: :desc, id: :desc).limit(5).to_a
    )
  end

  class Result
    attr_reader :total_balance_cents, :account_count, :transaction_count, :recent_transactions

    def initialize(total_balance_cents:, account_count:, transaction_count:, recent_transactions:)
      @total_balance_cents = total_balance_cents
      @account_count = account_count
      @transaction_count = transaction_count
      @recent_transactions = recent_transactions
    end
  end
end
