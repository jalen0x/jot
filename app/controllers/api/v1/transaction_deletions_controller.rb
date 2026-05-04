class Api::V1::TransactionDeletionsController < ApiController
  # POST /api/v1/transaction_deletions
  def create
    authorize :transaction_deletion
    result = TransactionBatchDeleter.new.delete_transactions(transactions: transactions)

    if result.deleted?
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
end
