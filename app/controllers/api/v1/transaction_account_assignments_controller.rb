class Api::V1::TransactionAccountAssignmentsController < ApiController
  # POST /api/v1/transaction_account_assignments
  def create
    authorize :transaction_account_assignment
    result = TransactionBatchAccountUpdater.new.update_account(
      transactions: transactions,
      account: account,
      destination_account: destination_account?
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

  def account
    current_user.accounts.kept.find(Account.decode_prefix_id(account_id) || account_id)
  end

  def account_id
    params[:account_id].to_s
  end

  def destination_account?
    ActiveModel::Type::Boolean.new.cast(params[:is_destination_account])
  end
end
