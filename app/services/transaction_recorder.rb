class TransactionRecorder
  def record_transaction(user:, attributes:, tag_ids:, picture_files: [], enforce_transaction_edit_scope: true)
    transaction = user.transactions.build
    draft = TransactionDrafter.new.draft_transaction(user: user, transaction: transaction, attributes: attributes, tag_ids: tag_ids)
    validate_transaction_edit_scope(transaction) if enforce_transaction_edit_scope

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

  def validate_transaction_edit_scope(transaction)
    return if transaction.transacted_at.blank?
    return if TransactionEditScope.new.editable?(transaction: transaction)

    transaction.errors.add(:base, TransactionEditScope::NOT_EDITABLE_MESSAGE)
  end

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
