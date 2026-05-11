class DashboardSummary
  AccountBalance = Struct.new(:currency_code, :balance_cents, keyword_init: true)
  PeriodAmount = Struct.new(:currency_code, :income_cents, :expense_cents, :net_cents, keyword_init: true)
  PeriodSummary = Struct.new(:key, :starts_on, :ends_on, :amounts, keyword_init: true)
  TrendBucket = Struct.new(:starts_on, :income_cents, :expense_cents, keyword_init: true)

  def summarize(user:)
    accounts = user.accounts.kept
    transactions = user.transactions.kept
    today = Time.zone.today

    Result.new(
      default_currency_code: user.user_preference&.default_currency_code || "USD",
      net_assets: account_balances(accounts),
      total_assets: account_balances(accounts.where("balance_cents > 0")),
      total_liabilities: account_liabilities(accounts.where("balance_cents < 0")),
      account_count: accounts.count,
      transaction_count: transactions.count,
      period_summaries: period_summaries(transactions, today),
      trend_buckets: trend_buckets(transactions, today, user.user_preference&.default_currency_code || "USD"),
      recent_transactions: transactions.includes(:account, :transaction_category, :transaction_tags).order(transacted_at: :desc, id: :desc).limit(5).to_a
    )
  end

  private

  def account_balances(accounts)
    accounts.group(:currency_code).sum(:balance_cents).sort.map do |currency_code, balance_cents|
      AccountBalance.new(currency_code: currency_code, balance_cents: balance_cents)
    end
  end

  def account_liabilities(accounts)
    accounts.group(:currency_code).sum(:balance_cents).sort.map do |currency_code, balance_cents|
      AccountBalance.new(currency_code: currency_code, balance_cents: balance_cents.abs)
    end
  end

  def period_summaries(transactions, today)
    {
      today: today.beginning_of_day..today.end_of_day,
      this_week: today.beginning_of_week.beginning_of_day..today.end_of_week.end_of_day,
      this_month: today.beginning_of_month.beginning_of_day..today.end_of_month.end_of_day,
      this_year: today.beginning_of_year.beginning_of_day..today.end_of_year.end_of_day
    }.map do |key, range|
      PeriodSummary.new(
        key: key,
        starts_on: range.begin.to_date,
        ends_on: range.end.to_date,
        amounts: period_amounts(transactions.where(transacted_at: range).includes(:account))
      )
    end
  end

  def period_amounts(transactions)
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

      PeriodAmount.new(
        currency_code: currency_code,
        income_cents: income_cents,
        expense_cents: expense_cents,
        net_cents: income_cents - expense_cents
      )
    end
  end

  def trend_buckets(transactions, today, currency_code)
    first_month = today.beginning_of_month.months_ago(5)
    months = (0..5).map { |offset| first_month.months_since(offset) }
    totals = Hash.new { |hash, key| hash[key] = { income_cents: 0, expense_cents: 0 } }

    transactions
      .includes(:account)
      .where(transacted_at: first_month.beginning_of_day..today.end_of_month.end_of_day, accounts: { currency_code: currency_code })
      .references(:accounts)
      .each do |transaction|
        next unless transaction.income? || transaction.expense?

        bucket = transaction.transacted_at.to_date.beginning_of_month
        if transaction.income?
          totals[bucket][:income_cents] += transaction.source_amount_cents
        else
          totals[bucket][:expense_cents] += transaction.source_amount_cents
        end
      end

    months.map do |month|
      TrendBucket.new(
        starts_on: month,
        income_cents: totals.dig(month, :income_cents).to_i,
        expense_cents: totals.dig(month, :expense_cents).to_i
      )
    end
  end

  class Result
    attr_reader :default_currency_code, :account_balances, :net_assets, :total_assets, :total_liabilities, :account_count, :transaction_count, :period_summaries, :trend_buckets, :recent_transactions

    def initialize(default_currency_code:, net_assets:, total_assets:, total_liabilities:, account_count:, transaction_count:, period_summaries:, trend_buckets:, recent_transactions:)
      @default_currency_code = default_currency_code
      @account_balances = net_assets
      @net_assets = net_assets
      @total_assets = total_assets
      @total_liabilities = total_liabilities
      @account_count = account_count
      @transaction_count = transaction_count
      @period_summaries = period_summaries
      @trend_buckets = trend_buckets
      @recent_transactions = recent_transactions
    end
  end
end
