class Api::V1::TransactionCategoryAssignmentsController < ApiController
  # POST /api/v1/transaction_category_assignments
  def create
    authorize :transaction_category_assignment
    result = TransactionBatchCategoryUpdater.new.update_category(
      transactions: transactions,
      category: transaction_category
    )

    if result.updated?
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

  def transaction_category
    current_user.transaction_categories.kept.find(TransactionCategory.decode_prefix_id(transaction_category_id) || transaction_category_id)
  end

  def transaction_category_id
    params[:transaction_category_id].to_s
  end
end
