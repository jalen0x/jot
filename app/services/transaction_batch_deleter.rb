class TransactionBatchDeleter
  def delete_transactions(transactions:)
    failed_transaction = nil

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

  class Result
    attr_reader :transaction

    def initialize(deleted:, transaction: nil)
      @deleted = deleted
      @transaction = transaction
    end

    def deleted? = @deleted
  end
end
