class TransactionBatchTagClearer
  def clear_tags(transactions:)
    failed_transaction = uneditable_transaction(transactions)
    return Result.new(cleared: false, transaction: failed_transaction) if failed_transaction.present?

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

  private

  def uneditable_transaction(transactions)
    transaction = TransactionEditScope.new.first_uneditable_transaction(transactions: transactions)
    return if transaction.blank?

    transaction.errors.add(:base, TransactionEditScope::NOT_EDITABLE_MESSAGE)
    transaction
  end
end
