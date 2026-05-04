class TransactionBatchTagClearer
  def clear_tags(transactions:)
    ActiveRecord::Base.transaction do
      TransactionTagging.where(ledger_transaction: transactions).delete_all
    end

    Result.new(cleared: true)
  end

  class Result
    def initialize(cleared:)
      @cleared = cleared
    end

    def cleared? = @cleared
  end
end
