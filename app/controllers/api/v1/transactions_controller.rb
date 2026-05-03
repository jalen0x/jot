class Api::V1::TransactionsController < ApiController
  # GET /api/v1/transactions
  def index
    authorize Transaction
    transactions = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params)

    render json: { transactions: transactions.map(&:as_json) }
  end

  # POST /api/v1/transactions
  def create
    authorize Transaction
    result = TransactionRecorder.new.record_transaction(user: current_user, attributes: transaction_params, tag_ids: transaction_tag_ids)

    if result.recorded?
      render json: { transaction: result.transaction.as_json }, status: :created
    else
      render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def filter_params
    params.permit(:transaction_kind)
  end

  def transaction_params
    params.expect(transaction: [
      :transaction_kind,
      :account_id,
      :destination_account_id,
      :transaction_category_id,
      :transacted_at,
      :timezone_utc_offset_minutes,
      :source_amount_cents,
      :destination_amount_cents,
      :hide_amount,
      :comment,
      transaction_tag_ids: []
    ])
  end

  def transaction_tag_ids
    Array(transaction_params[:transaction_tag_ids]).reject(&:blank?)
  end
end
