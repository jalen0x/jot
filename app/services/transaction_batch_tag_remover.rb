class TransactionBatchTagRemover
  def remove_tags(transactions:, tags:)
    failed_transaction = transactions.find { |transaction| !transaction.editable? }
    if failed_transaction
      failed_transaction.errors.add(:base, Transaction::NOT_EDITABLE_MESSAGE)
      return Result.new(removed: false, transaction: failed_transaction)
    end

    ActiveRecord::Base.transaction do
      TransactionTagging.where(ledger_transaction: transactions, transaction_tag: tags).delete_all
    end

    Result.new(removed: true)
  end

  class Result
    attr_reader :transaction

    def initialize(removed:, transaction: nil)
      @removed = removed
      @transaction = transaction
    end

    def removed? = @removed
  end
end
