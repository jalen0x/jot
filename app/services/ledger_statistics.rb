class LedgerStatistics
  def summarize_transactions(user:, range:)
    transactions = user.transactions.kept.includes(:transaction_category).where(transacted_at: range)
    income_cents = transactions.income.sum(:source_amount_cents)
    expense_cents = transactions.expense.sum(:source_amount_cents)

    Result.new(
      income_cents: income_cents,
      expense_cents: expense_cents,
      net_cents: income_cents - expense_cents,
      category_totals: category_totals(transactions)
    )
  end

  private

  def category_totals(transactions)
    totals = Hash.new(0)

    transactions.each do |transaction|
      next unless transaction.income? || transaction.expense?

      amount = transaction.income? ? transaction.source_amount_cents : -transaction.source_amount_cents
      totals[transaction.transaction_category.name] += amount
    end

    totals
  end

  class Result
    attr_reader :income_cents, :expense_cents, :net_cents, :category_totals

    def initialize(income_cents:, expense_cents:, net_cents:, category_totals:)
      @income_cents = income_cents
      @expense_cents = expense_cents
      @net_cents = net_cents
      @category_totals = category_totals
    end
  end
end
