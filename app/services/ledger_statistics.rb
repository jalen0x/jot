class LedgerStatistics
  Amount = Struct.new(:currency_code, :income_cents, :expense_cents, :net_cents, keyword_init: true)
  CategoryAmount = Struct.new(:name, :currency_code, :amount_cents, keyword_init: true)

  def summarize_transactions(user:, range:, filters: {})
    transactions = LedgerQuery.new.list_transactions(user: user, filters: filters).where(transacted_at: range).to_a
    income_cents = transactions.select(&:income?).sum(&:source_amount_cents)
    expense_cents = transactions.select(&:expense?).sum(&:source_amount_cents)

    Result.new(
      income_cents: income_cents,
      expense_cents: expense_cents,
      net_cents: income_cents - expense_cents,
      amounts: amounts(transactions),
      category_amounts: category_amounts(transactions),
      category_totals: category_totals(transactions),
      account_totals: account_totals(transactions)
    )
  end

  private

  def amounts(transactions)
    totals = Hash.new { |hash, key| hash[key] = { income_cents: 0, expense_cents: 0 } }

    transactions.each do |transaction|
      next unless transaction.income? || transaction.expense?

      currency_code = transaction.account.currency_code
      if transaction.income?
        totals[currency_code][:income_cents] += transaction.source_amount_cents
      else
        totals[currency_code][:expense_cents] += transaction.source_amount_cents
      end
    end

    totals.keys.sort.map do |currency_code|
      income_cents = totals.dig(currency_code, :income_cents)
      expense_cents = totals.dig(currency_code, :expense_cents)

      Amount.new(
        currency_code: currency_code,
        income_cents: income_cents,
        expense_cents: expense_cents,
        net_cents: income_cents - expense_cents
      )
    end
  end

  def category_amounts(transactions)
    totals = Hash.new(0)

    transactions.each do |transaction|
      next unless transaction.income? || transaction.expense?

      key = [ transaction.transaction_category.name, transaction.account.currency_code ]
      totals[key] += signed_amount(transaction)
    end

    totals.keys.sort.map do |name, currency_code|
      CategoryAmount.new(name: name, currency_code: currency_code, amount_cents: totals.fetch([ name, currency_code ]))
    end
  end

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
    attr_reader :income_cents, :expense_cents, :net_cents, :amounts, :category_amounts, :category_totals, :account_totals

    def initialize(income_cents:, expense_cents:, net_cents:, amounts:, category_amounts:, category_totals:, account_totals:)
      @income_cents = income_cents
      @expense_cents = expense_cents
      @net_cents = net_cents
      @amounts = amounts
      @category_amounts = category_amounts
      @category_totals = category_totals
      @account_totals = account_totals
    end

    def as_json(_options = {})
      {
        income_cents: income_cents,
        expense_cents: expense_cents,
        net_cents: net_cents,
        category_totals: category_totals,
        account_totals: account_totals
      }
    end
  end
end
