class Api::V1::TransactionTagClearancesController < ApiController
  # POST /api/v1/transaction_tag_clearances
  def create
    authorize :transaction_tag_clearance
    result = TransactionBatchTagClearer.new.clear_tags(transactions: transactions)

    if result.cleared?
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
