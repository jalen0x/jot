class Api::V1::TransactionsController < ApiController
  # GET /api/v1/transactions
  def index
    authorize Transaction
    transactions = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params)

    render json: { transactions: transactions.map(&:as_json) }
  end

  # GET /api/v1/transactions/:id
  def show
    transaction = scoped_transaction
    authorize transaction

    render json: { transaction: transaction }
  end

  # POST /api/v1/transactions
  def create
    authorize Transaction
    result = TransactionRecorder.new.record_transaction(user: current_user, attributes: transaction_params, tag_ids: transaction_tag_ids)

    if result.recorded?
      render json: { transaction: result.transaction }, status: :created
    else
      render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/v1/transactions/:id
  def update
    transaction = scoped_transaction
    authorize transaction
    result = TransactionUpdater.new.update_transaction(transaction: transaction, attributes: transaction_params, tag_ids: transaction_tag_ids)

    if result.updated?
      render json: { transaction: result.transaction }
    else
      render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/transactions/:id
  def destroy
    transaction = scoped_transaction
    authorize transaction
    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    if result.deleted?
      head :no_content
    else
      render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def filter_params
    params.permit(
      :transaction_kind,
      :account_id,
      :transaction_category_id,
      :tag_id,
      :keyword,
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
      transaction_tag_ids: [],
      geo_location: [ :latitude, :longitude ]
    ])
  end

  def transaction_tag_ids
    Array(transaction_params[:transaction_tag_ids]).reject(&:blank?)
  end

  def scoped_transaction
    policy_scope(Transaction).kept.find(params[:id])
  end
end
