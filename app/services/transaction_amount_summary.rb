class TransactionAmountSummary
  Amount = Struct.new(:currency_code, :income_cents, :expense_cents, :net_cents, keyword_init: true) do
    def as_json(_options = {})
      {
        currency_code: currency_code,
        income_cents: income_cents,
        expense_cents: expense_cents,
        net_cents: net_cents
      }
    end
  end

  def summarize_transactions(user:, range:, filters: {})
    totals = Hash.new { |hash, key| hash[key] = { income_cents: 0, expense_cents: 0 } }

    LedgerQuery.new.list_transactions(user: user, filters: filters).where(transacted_at: range).each do |transaction|
      next unless transaction.income? || transaction.expense?

      currency_code = transaction.account.currency_code
      if transaction.income?
        totals[currency_code][:income_cents] += transaction.source_amount_cents
      else
        totals[currency_code][:expense_cents] += transaction.source_amount_cents
      end
    end

    Result.new(range: range, amounts: amounts(totals))
  end

  private

  def amounts(totals)
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

  class Result
    attr_reader :range, :amounts

    def initialize(range:, amounts:)
      @range = range
      @amounts = amounts
    end

    def as_json(_options = {})
      {
        amounts: amounts.map(&:as_json)
      }
    end
  end
end
