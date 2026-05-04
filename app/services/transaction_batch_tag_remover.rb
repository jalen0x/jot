class TransactionBatchTagRemover
  def remove_tags(transactions:, tags:)
    ActiveRecord::Base.transaction do
      TransactionTagging.where(ledger_transaction: transactions, transaction_tag: tags).delete_all
    end

    Result.new(removed: true)
  end

  class Result
    def initialize(removed:)
      @removed = removed
    end

    def removed? = @removed
  end
end
