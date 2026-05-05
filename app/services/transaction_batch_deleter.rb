class TransactionBatchDeleter
  def delete_transactions(transactions:)
    failed_transaction = first_undeletable_transaction(transactions)
    return Result.new(deleted: false, transaction: failed_transaction) if failed_transaction.present?

    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        result = TransactionReversal.new.delete_transaction(transaction: transaction)
        next if result.deleted?

        failed_transaction = result.transaction
        raise ActiveRecord::Rollback
      end
    end

    return Result.new(deleted: false, transaction: failed_transaction) if failed_transaction.present?

    Result.new(deleted: true)
  end

  private

  def first_undeletable_transaction(transactions)
    transactions.find do |transaction|
      message = deletion_error(transaction)
      transaction.errors.add(:base, message) if message.present?
      message.present?
    end
  end

  def deletion_error(transaction)
    return "Transaction is already deleted" if transaction.discarded?
    TransactionEditScope::NOT_EDITABLE_MESSAGE unless TransactionEditScope.new.editable?(transaction: transaction)
  end

  class Result
    attr_reader :transaction

    def initialize(deleted:, transaction: nil)
      @deleted = deleted
      @transaction = transaction
    end

    def deleted? = @deleted
  end
end
