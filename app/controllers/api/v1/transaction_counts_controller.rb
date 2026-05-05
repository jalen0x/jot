class Api::V1::TransactionCountsController < ApiController
  # GET /api/v1/transaction_count
  def show
    authorize :transaction_count
    count = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params).count

    render json: { count: count }
  end

  private

  def filter_params
    ledger_filter_params(include_amounts: true, include_dates: true)
  end
end
