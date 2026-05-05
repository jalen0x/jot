class TransactionBatchTagRemover
  def remove_tags(transactions:, tags:)
    failed_transaction = uneditable_transaction(transactions)
    return Result.new(removed: false, transaction: failed_transaction) if failed_transaction.present?

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

  private

  def uneditable_transaction(transactions)
    transaction = TransactionEditScope.new.first_uneditable_transaction(transactions: transactions)
    return if transaction.blank?

    transaction.errors.add(:base, TransactionEditScope::NOT_EDITABLE_MESSAGE)
    transaction
  end
end
