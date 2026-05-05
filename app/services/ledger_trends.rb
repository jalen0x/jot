class LedgerTrends
  Bucket = Struct.new(:starts_on, :income_cents, :expense_cents, :net_cents, keyword_init: true) do
    def as_json(_options = {})
      {
        starts_on: starts_on.iso8601,
        income_cents: income_cents,
        expense_cents: expense_cents,
        net_cents: net_cents
      }
    end
  end

  def build_transaction_trends(user:, range:, aggregation:, filters: {})
    transactions = LedgerQuery.new.list_transactions(user: user, filters: filters).where(transacted_at: range)
    totals = totals_by_bucket(transactions, aggregation)
    buckets = bucket_starts(range, aggregation).map do |starts_on|
      income_cents = totals.dig(starts_on, :income_cents).to_i
      expense_cents = totals.dig(starts_on, :expense_cents).to_i

      Bucket.new(
        starts_on: starts_on,
        income_cents: income_cents,
        expense_cents: expense_cents,
        net_cents: income_cents - expense_cents
      )
    end

    Result.new(range: range, aggregation: aggregation.to_s, buckets: buckets)
  end

  private

  def totals_by_bucket(transactions, aggregation)
    totals = Hash.new { |hash, key| hash[key] = { income_cents: 0, expense_cents: 0 } }

    transactions.each do |transaction|
      next unless transaction.income? || transaction.expense?

      starts_on = bucket_start(transaction.transacted_at.to_date, aggregation)
      if transaction.income?
        totals[starts_on][:income_cents] += transaction.source_amount_cents
      else
        totals[starts_on][:expense_cents] += transaction.source_amount_cents
      end
    end

    totals
  end

  def bucket_starts(range, aggregation)
    case aggregation.to_s
    when "day"
      (range.begin.to_date..range.end.to_date).to_a
    when "month"
      month_starts(range.begin.to_date.beginning_of_month, range.end.to_date.beginning_of_month)
    else
      raise ArgumentError, "Unsupported trend aggregation"
    end
  end

  def bucket_start(date, aggregation)
    aggregation.to_s == "month" ? date.beginning_of_month : date
  end

  def month_starts(first_month, last_month)
    months = []
    current_month = first_month
    while current_month <= last_month
      months << current_month
      current_month = current_month.next_month
    end
    months
  end

  class Result
    attr_reader :range, :aggregation, :buckets

    def initialize(range:, aggregation:, buckets:)
      @range = range
      @aggregation = aggregation
      @buckets = buckets
    end

    def as_json(_options = {})
      {
        aggregation: aggregation,
        buckets: buckets.map(&:as_json)
      }
    end
  end
end
