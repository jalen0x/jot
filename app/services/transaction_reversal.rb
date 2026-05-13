class TransactionReversal
  def delete_transaction(transaction:, enforce_transaction_edit_scope: true)
    if transaction.discarded?
      transaction.errors.add(:base, "Transaction is already deleted")
      return Result.new(deleted: false, transaction: transaction)
    end

    if enforce_transaction_edit_scope && !transaction.editable?
      transaction.errors.add(:base, Transaction::NOT_EDITABLE_MESSAGE)
      return Result.new(deleted: false, transaction: transaction)
    end

    transaction.pictures.purge if transaction.pictures.attached?

    ActiveRecord::Base.transaction do
      AccountBalanceLedger.new.reverse(transaction)
      transaction.discard!
    end

    Result.new(deleted: true, transaction: transaction)
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
