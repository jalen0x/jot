class TransactionReversal
  def delete_transaction(transaction:)
    if transaction.discarded?
      transaction.errors.add(:base, "Transaction is already deleted")
      return Result.new(deleted: false, transaction: transaction)
    end

    unless TransactionEditScope.new.editable?(transaction: transaction)
      transaction.errors.add(:base, "Transaction is outside the editable date range")
      return Result.new(deleted: false, transaction: transaction)
    end

    transaction.pictures.purge if transaction.pictures.attached?

    ActiveRecord::Base.transaction do
      reverse_balances(transaction)
      transaction.discard!
    end

    Result.new(deleted: true, transaction: transaction)
  end

  private

  def reverse_balances(transaction)
    case transaction.transaction_kind
    when "balance_adjustment"
      transaction.account.update!(balance_cents: transaction.account.balance_cents - transaction.source_amount_cents)
    when "income"
      transaction.account.update!(balance_cents: transaction.account.balance_cents - transaction.source_amount_cents)
    when "expense"
      transaction.account.update!(balance_cents: transaction.account.balance_cents + transaction.source_amount_cents)
    when "transfer"
      transaction.account.update!(balance_cents: transaction.account.balance_cents + transaction.source_amount_cents)
      transaction.destination_account.update!(balance_cents: transaction.destination_account.balance_cents - transaction.destination_amount_cents)
    end
  end

  class Result
    attr_reader :transaction

    def initialize(deleted:, transaction:)
      @deleted = deleted
      @transaction = transaction
    end

    def deleted? = @deleted
  end
end
