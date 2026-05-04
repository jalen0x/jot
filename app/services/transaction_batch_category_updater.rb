class TransactionBatchCategoryUpdater
  def update_category(transactions:, category:)
    failed_transaction = nil

    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        transaction.transaction_category = category
        validate_category_type(transaction)

        unless transaction.errors.empty? && transaction.save
          failed_transaction = transaction
          raise ActiveRecord::Rollback
        end
      end
    end

    return Result.new(updated: false, transaction: failed_transaction) if failed_transaction.present?

    Result.new(updated: true)
  end

  private

  def validate_category_type(transaction)
    return if transaction.balance_adjustment? || transaction.transaction_category.blank?
    return if transaction.transaction_category.category_type == transaction.transaction_kind

    transaction.errors.add(:transaction_category, "does not match transaction type")
  end

  class Result
    attr_reader :transaction

    def initialize(updated:, transaction: nil)
      @updated = updated
      @transaction = transaction
    end

    def updated? = @updated
  end
end
