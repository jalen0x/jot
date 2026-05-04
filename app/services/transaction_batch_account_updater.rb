class TransactionBatchAccountUpdater
  def update_account(transactions:, account:, destination_account: false)
    failed_transaction = transactions.find { |transaction| invalid_transaction?(transaction, account, destination_account) }
    return Result.new(updated: false, transaction: failed_transaction) if failed_transaction.present?

    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        destination_account ? move_destination_account(transaction, account) : move_source_account(transaction, account)
      end
    end

    Result.new(updated: true)
  end

  private

  def invalid_transaction?(transaction, account, destination_account)
    if destination_account
      validate_destination_account_update(transaction, account)
    else
      validate_source_account_update(transaction, account)
    end

    transaction.errors.any?
  end

  def validate_destination_account_update(transaction, account)
    unless transaction.transfer?
      transaction.errors.add(:destination_account, "can only be updated for transfers")
      return
    end

    transaction.errors.add(:destination_account, "must differ from source account") if transaction.account == account
    if transaction.destination_account.present? && transaction.destination_account.currency_code != account.currency_code
      transaction.errors.add(:destination_account, "must use the current destination account currency")
    end
  end

  def validate_source_account_update(transaction, account)
    transaction.errors.add(:account, "must differ from destination account") if transaction.transfer? && transaction.destination_account == account
    transaction.errors.add(:account, "must use the current account currency") if transaction.account.currency_code != account.currency_code
  end

  def move_source_account(transaction, account)
    old_account = transaction.account
    return if old_account == account

    delta_cents = source_balance_delta(transaction)
    adjust_balance(old_account, -delta_cents)
    transaction.update!(account: account)
    adjust_balance(account, delta_cents)
  end

  def move_destination_account(transaction, account)
    old_account = transaction.destination_account
    return if old_account == account

    delta_cents = transaction.destination_amount_cents
    adjust_balance(old_account, -delta_cents)
    transaction.update!(destination_account: account)
    adjust_balance(account, delta_cents)
  end

  def source_balance_delta(transaction)
    case transaction.transaction_kind
    when "balance_adjustment", "income"
      transaction.source_amount_cents
    when "expense", "transfer"
      -transaction.source_amount_cents
    end
  end

  def adjust_balance(account, delta_cents)
    account.update!(balance_cents: account.reload.balance_cents + delta_cents)
  end

  class Result
    attr_reader :transaction

    def initialize(updated:, transaction: nil)
      @updated = updated
      @transaction = transaction
    end

    def updated? = @updated
  end
end
