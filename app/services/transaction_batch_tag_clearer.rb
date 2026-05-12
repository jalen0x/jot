class TransactionBatchTagClearer
  def clear_tags(transactions:)
    failed_transaction = transactions.find { |transaction| !transaction.editable? }
    if failed_transaction
      failed_transaction.errors.add(:base, Transaction::NOT_EDITABLE_MESSAGE)
      return Result.new(cleared: false, transaction: failed_transaction)
    end

    ActiveRecord::Base.transaction do
      TransactionTagging.where(ledger_transaction: transactions).delete_all
    end

    Result.new(cleared: true)
  end

  class Result
    attr_reader :transaction

    def initialize(cleared:, transaction: nil)
      @cleared = cleared
      @transaction = transaction
    end

    def cleared? = @cleared
  end
end
