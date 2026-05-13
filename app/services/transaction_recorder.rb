class TransactionRecorder
  def record_transaction(user:, attributes:, tag_ids:, picture_files: [], enforce_transaction_edit_scope: true)
    transaction = user.transactions.build
    draft = TransactionDrafter.new.draft_transaction(user: user, transaction: transaction, attributes: attributes, tag_ids: tag_ids)
    transaction.errors.add(:base, Transaction::NOT_EDITABLE_MESSAGE) if enforce_transaction_edit_scope && !transaction.editable?

    return Result.new(recorded: false, transaction: transaction) unless draft.valid?

    ActiveRecord::Base.transaction do
      transaction.save!
      draft.tags.each do |tag|
        transaction.transaction_taggings.create!(user: user, transaction_tag: tag)
      end
      transaction.pictures.attach(picture_attachables(picture_files))
      AccountBalanceLedger.new.apply(transaction)
    end

    transaction.association(:transaction_tags).target = draft.tags
    Result.new(recorded: true, transaction: transaction)
  end

  private

  def picture_attachables(picture_files)
    Array(picture_files).reject(&:blank?).map do |file|
      next file unless file.respond_to?(:tempfile)

      {
        io: file.tempfile,
        filename: file.original_filename,
        content_type: file.content_type,
        identify: false
      }
    end
  end

  class Result
    attr_reader :transaction

    def initialize(recorded:, transaction:)
      @recorded = recorded
      @transaction = transaction
    end

    def recorded? = @recorded
  end
end
