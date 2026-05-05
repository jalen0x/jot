class Api::V1::TransactionTagAssignmentsController < ApiController
  # POST /api/v1/transaction_tag_assignments
  def create
    authorize :transaction_tag_assignment
    result = TransactionBatchTagAdder.new.add_tags(transactions: transactions, tags: transaction_tags)

    if result.added?
      head :no_content
    else
      render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def transactions
    transaction_ids.map do |id|
      policy_scope(Transaction).kept.find(Transaction.decode_prefix_id(id) || id)
    end
  end

  def transaction_ids
    Array(params.permit(transaction_ids: [])[:transaction_ids]).reject(&:blank?).map(&:to_s).uniq
  end

  def transaction_tags
    transaction_tag_ids.map do |id|
      current_user.transaction_tags.kept.find(TransactionTag.decode_prefix_id(id) || id)
    end
  end

  def transaction_tag_ids
    Array(params.permit(transaction_tag_ids: [])[:transaction_tag_ids]).reject(&:blank?).map(&:to_s).uniq
  end
end
