class TransactionBatchTagAdder
  def add_tags(transactions:, tags:)
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
    def initialize(added:)
      @added = added
    end

    def added? = @added
  end
end
