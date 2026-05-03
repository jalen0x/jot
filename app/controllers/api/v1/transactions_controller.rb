class Api::V1::TransactionsController < ApiController
  # GET /api/v1/transactions
  def index
    authorize Transaction
    transactions = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params)

    render json: { transactions: transactions.map(&:as_json) }
  end

  private

  def filter_params
    params.permit(:transaction_kind)
  end
end
