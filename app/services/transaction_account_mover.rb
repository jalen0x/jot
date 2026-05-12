class TransactionAccountMover
  def move_between_accounts(user:, from_account:, to_account:)
    errors = validation_errors(user, from_account, to_account)
    return Result.new(moved: false, errors: errors) if errors.any?

    source_transactions = source_transactions(user, from_account)
    destination_transactions = destination_transactions(user, from_account)
    if transfer_conflict(source_transactions, destination_transactions, to_account).present?
      return Result.new(moved: false, errors: [ "Move would make a transfer use the same source and destination account" ])
    end

    ActiveRecord::Base.transaction do
      source_transactions.each { |transaction| move_source_account(transaction, to_account) }
      destination_transactions.each { |transaction| move_destination_account(transaction, to_account) }
    end

    Result.new(moved: true)
  end

  private

  def validation_errors(user, from_account, to_account)
    errors = []
    errors << "From account must differ from to account" if from_account == to_account
    errors << "Accounts must use the same currency" if from_account.currency_code != to_account.currency_code
    errors << "Accounts must belong to the same user" if from_account.user_id != user.id || to_account.user_id != user.id
    errors
  end

  def source_transactions(user, from_account)
    user.transactions.kept.where(account: from_account).to_a
  end

  def destination_transactions(user, from_account)
    user.transactions.kept.transfer.where(destination_account: from_account).to_a
  end

  def transfer_conflict(source_transactions, destination_transactions, to_account)
    source_transactions.find { |transaction| transaction.transfer? && transaction.destination_account == to_account } ||
      destination_transactions.find { |transaction| transaction.account == to_account }
  end

  def move_source_account(transaction, account)
    delta_cents = transaction.source_balance_delta
    ledger = AccountBalanceLedger.new
    ledger.adjust(transaction.account, -delta_cents)
    transaction.update!(account: account)
    ledger.adjust(account, delta_cents)
  end

  def move_destination_account(transaction, account)
    delta_cents = transaction.destination_amount_cents
    ledger = AccountBalanceLedger.new
    ledger.adjust(transaction.destination_account, -delta_cents)
    transaction.update!(destination_account: account)
    ledger.adjust(account, delta_cents)
  end

  class Result
    attr_reader :errors

    def initialize(moved:, errors: [])
      @moved = moved
      @errors = errors
    end

    def moved? = @moved
  end
end
