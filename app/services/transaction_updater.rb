class TransactionUpdater
  def update_transaction(transaction:, attributes:, tag_ids:)
    unless transaction.editable?
      transaction.errors.add(:base, Transaction::NOT_EDITABLE_MESSAGE)
      return Result.new(updated: false, transaction: transaction)
    end

    original = transaction.dup
    draft = TransactionDrafter.new.draft_transaction(user: transaction.user, transaction: transaction, attributes: attributes, tag_ids: tag_ids)

    return Result.new(updated: false, transaction: transaction) unless draft.valid?

    ledger = AccountBalanceLedger.new
    ActiveRecord::Base.transaction do
      ledger.reverse(original)
      transaction.save!
      TransactionTagging.where(ledger_transaction: transaction).delete_all
      draft.tags.each do |tag|
        transaction.transaction_taggings.create!(user: transaction.user, transaction_tag: tag)
      end
      ledger.apply(transaction)
    end

    transaction.association(:transaction_tags).target = draft.tags
    Result.new(updated: true, transaction: transaction)
  end

  class Result
    attr_reader :transaction

    def initialize(updated:, transaction:)
      @updated = updated
      @transaction = transaction
    end

    def updated? = @updated
  end
end
