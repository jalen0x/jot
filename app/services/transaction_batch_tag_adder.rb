class TransactionBatchTagAdder
  def add_tags(transactions:, tags:)
    failed_transaction = uneditable_transaction(transactions)
    return Result.new(added: false, transaction: failed_transaction) if failed_transaction.present?

    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        tags.each do |tag|
          TransactionTagging.find_or_create_by!(user: transaction.user, ledger_transaction: transaction, transaction_tag: tag)
        end
      end
    end

    Result.new(added: true)
  end

  class Result
    attr_reader :transaction

    def initialize(added:, transaction: nil)
      @added = added
      @transaction = transaction
    end

    def added? = @added
  end

  private

  def uneditable_transaction(transactions)
    transaction = TransactionEditScope.new.first_uneditable_transaction(transactions: transactions)
    return if transaction.blank?

    transaction.errors.add(:base, TransactionEditScope::NOT_EDITABLE_MESSAGE)
    transaction
  end
end
