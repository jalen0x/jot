class TransactionBatchTagAdder
  def add_tags(transactions:, tags:)
    failed_transaction = transactions.find { |transaction| !transaction.editable? }
    if failed_transaction
      failed_transaction.errors.add(:base, Transaction::NOT_EDITABLE_MESSAGE)
      return Result.new(added: false, transaction: failed_transaction)
    end

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
end
