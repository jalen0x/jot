class Api::V1::TransactionCountsController < ApiController
  # GET /api/v1/transaction_count
  def show
    authorize :transaction_count
    count = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params).count

    render json: { count: count }
  end

  private

  def filter_params
    params.permit(
      :transaction_kind,
      :account_id,
      :transaction_category_id,
      :tag_id,
      tag_filter: [
        :without_tags,
        {
          include_any_ids: [],
          include_all_ids: [],
          exclude_any_ids: [],
          exclude_all_ids: []
        }
      ]
    )
  end
end
