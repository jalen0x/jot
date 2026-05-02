class AccountCreator
  def create_account(user:, attributes:, opening_balance_cents:)
    account = user.accounts.build(attributes.merge(balance_cents: opening_balance_cents))

    unless account.valid?
      return Result.new(created: false, account: account)
    end

    ActiveRecord::Base.transaction do
      account.save!
      create_opening_balance_transaction(account, opening_balance_cents) if opening_balance_cents != 0
    end

    Result.new(created: true, account: account)
  end

  private

  def create_opening_balance_transaction(account, opening_balance_cents)
    account.user.transactions.create!(
      account: account,
      transaction_kind: :balance_adjustment,
      transacted_at: Time.current,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: opening_balance_cents,
      destination_amount_cents: 0
    )
  end

  class Result
    attr_reader :account

    def initialize(created:, account:)
      @created = created
      @account = account
    end

    def created? = @created
  end
end
