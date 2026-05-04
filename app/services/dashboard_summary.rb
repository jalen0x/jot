class DashboardSummary
  AccountBalance = Struct.new(:currency_code, :balance_cents, keyword_init: true)

  def summarize(user:)
    accounts = user.accounts.kept
    transactions = user.transactions.kept

    Result.new(
      account_balances: account_balances(accounts),
      account_count: accounts.count,
      transaction_count: transactions.count,
      recent_transactions: transactions.includes(:account, :transaction_category).order(transacted_at: :desc, id: :desc).limit(5).to_a
    )
  end

  private

  def account_balances(accounts)
    accounts.group(:currency_code).sum(:balance_cents).sort.map do |currency_code, balance_cents|
      AccountBalance.new(currency_code: currency_code, balance_cents: balance_cents)
    end
  end

  class Result
    attr_reader :account_balances, :account_count, :transaction_count, :recent_transactions

    def initialize(account_balances:, account_count:, transaction_count:, recent_transactions:)
      @account_balances = account_balances
      @account_count = account_count
      @transaction_count = transaction_count
      @recent_transactions = recent_transactions
    end
  end
end
