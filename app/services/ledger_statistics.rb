class LedgerStatistics
  def summarize_transactions(user:, range:, filters: {})
    transactions = LedgerQuery.new.list_transactions(user: user, filters: filters).where(transacted_at: range).to_a
    income_cents = transactions.select(&:income?).sum(&:source_amount_cents)
    expense_cents = transactions.select(&:expense?).sum(&:source_amount_cents)

    Result.new(
      income_cents: income_cents,
      expense_cents: expense_cents,
      net_cents: income_cents - expense_cents,
      category_totals: category_totals(transactions),
      account_totals: account_totals(transactions)
    )
  end

  private

  def category_totals(transactions)
    totals = Hash.new(0)

    transactions.each do |transaction|
      next unless transaction.income? || transaction.expense?

      totals[transaction.transaction_category.name] += signed_amount(transaction)
    end

    totals
  end

  def account_totals(transactions)
    totals = Hash.new(0)

    transactions.each do |transaction|
      next unless transaction.income? || transaction.expense?

      totals[transaction.account.name] += signed_amount(transaction)
    end

    totals
  end

  def signed_amount(transaction)
    transaction.income? ? transaction.source_amount_cents : -transaction.source_amount_cents
  end

  class Result
    attr_reader :income_cents, :expense_cents, :net_cents, :category_totals, :account_totals

    def initialize(income_cents:, expense_cents:, net_cents:, category_totals:, account_totals:)
      @income_cents = income_cents
      @expense_cents = expense_cents
      @net_cents = net_cents
      @category_totals = category_totals
      @account_totals = account_totals
    end
  end
end
