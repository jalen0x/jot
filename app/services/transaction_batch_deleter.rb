class TransactionBatchDeleter
  def delete_transactions(transactions:, enforce_transaction_edit_scope: true)
    failed_transaction = first_undeletable_transaction(transactions, enforce_transaction_edit_scope: enforce_transaction_edit_scope)
    return Result.new(deleted: false, transaction: failed_transaction) if failed_transaction.present?

    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        result = TransactionReversal.new.delete_transaction(
          transaction: transaction,
          enforce_transaction_edit_scope: enforce_transaction_edit_scope
        )
        next if result.deleted?

        failed_transaction = result.transaction
        raise ActiveRecord::Rollback
      end
    end

    return Result.new(deleted: false, transaction: failed_transaction) if failed_transaction.present?

    Result.new(deleted: true)
  end

  private

  def first_undeletable_transaction(transactions, enforce_transaction_edit_scope:)
    transactions.find do |transaction|
      message = deletion_error(transaction, enforce_transaction_edit_scope: enforce_transaction_edit_scope)
      transaction.errors.add(:base, message) if message.present?
      message.present?
    end
  end

  def deletion_error(transaction, enforce_transaction_edit_scope:)
    return "Transaction is already deleted" if transaction.discarded?
    return unless enforce_transaction_edit_scope

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
