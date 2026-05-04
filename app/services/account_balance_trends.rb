class AccountBalanceTrends
  AccountBalance = Struct.new(:account, :opening_balance_cents, :closing_balance_cents, keyword_init: true)
  Bucket = Struct.new(:starts_on, :account_balances, keyword_init: true)

  def build_account_balance_trends(user:, range:)
    accounts = user.accounts.kept.order(:display_order, :name, :id).to_a
    account_ids = accounts.map(&:id)
    balances = opening_balances(user: user, account_ids: account_ids, starts_at: range.begin)
    effects_by_date = daily_effects(user: user, account_ids: account_ids, range: range)

    buckets = (range.begin.to_date..range.end.to_date).map do |date|
      opening_balances = balances.dup
      effects_by_date.fetch(date, {}).each { |account_id, amount| balances[account_id] += amount }

      Bucket.new(
        starts_on: date,
        account_balances: accounts.map do |account|
          AccountBalance.new(
            account: account,
            opening_balance_cents: opening_balances[account.id],
            closing_balance_cents: balances[account.id]
          )
        end
      )
    end

    Result.new(range: range, buckets: buckets)
  end

  private

  def opening_balances(user:, account_ids:, starts_at:)
    balances = empty_balances(account_ids)
    relevant_transactions(user.transactions.kept.where("transacted_at < ?", starts_at), account_ids).find_each do |transaction|
      apply_effect(balances, transaction)
    end
    balances
  end

  def daily_effects(user:, account_ids:, range:)
    effects = Hash.new { |hash, key| hash[key] = empty_balances(account_ids) }
    relevant_transactions(user.transactions.kept.where(transacted_at: range), account_ids).find_each do |transaction|
      apply_effect(effects[transaction.transacted_at.to_date], transaction)
    end
    effects
  end

  def relevant_transactions(scope, account_ids)
    return Transaction.none if account_ids.empty?

    scope.where("account_id IN (:account_ids) OR destination_account_id IN (:account_ids)", account_ids: account_ids)
  end

  def empty_balances(account_ids)
    account_ids.index_with(0)
  end

  def apply_effect(balances, transaction)
    case transaction.transaction_kind
    when "balance_adjustment", "income"
      add_effect(balances, transaction.account_id, transaction.source_amount_cents)
    when "expense"
      add_effect(balances, transaction.account_id, -transaction.source_amount_cents)
    when "transfer"
      add_effect(balances, transaction.account_id, -transaction.source_amount_cents)
      add_effect(balances, transaction.destination_account_id, transaction.destination_amount_cents)
    end
  end

  def add_effect(balances, account_id, amount)
    return unless balances.key?(account_id)

    balances[account_id] += amount
  end

  class Result
    attr_reader :range, :buckets

    def initialize(range:, buckets:)
      @range = range
      @buckets = buckets
    end
  end
end
