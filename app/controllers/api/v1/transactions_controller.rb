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

  # PATCH/PUT /api/v1/transactions/:id
  def update
    transaction = scoped_transaction
    authorize transaction
    result = TransactionUpdater.new.update_transaction(transaction: transaction, attributes: transaction_params, tag_ids: transaction_tag_ids)

    if result.updated?
      render json: { transaction: result.transaction.as_json }
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

  # POST /api/v1/transactions/batch_delete
  def batch_delete
    authorize Transaction
    result = TransactionBatchDeleter.new.delete_transactions(transactions: batch_delete_transactions)

    if result.deleted?
      head :no_content
    else
      render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
    end
  end

  # POST /api/v1/transactions/batch_update_category
  def batch_update_category
    authorize Transaction
    result = TransactionBatchCategoryUpdater.new.update_category(
      transactions: batch_update_transactions,
      category: batch_update_category_target
    )

    if result.updated?
      head :no_content
    else
      render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
    end
  end

  # POST /api/v1/transactions/batch_update_account
  def batch_update_account
    authorize Transaction
    result = TransactionBatchAccountUpdater.new.update_account(
      transactions: batch_update_transactions,
      account: batch_update_account_target,
      destination_account: batch_update_destination_account?
    )

    if result.updated?
      head :no_content
    else
      render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
    end
  end

  # POST /api/v1/transactions/batch_add_tags
  def batch_add_tags
    authorize Transaction
    TransactionBatchTagAdder.new.add_tags(transactions: batch_update_transactions, tags: batch_tags)

    head :no_content
  end

  # POST /api/v1/transactions/batch_remove_tags
  def batch_remove_tags
    authorize Transaction
    TransactionBatchTagRemover.new.remove_tags(transactions: batch_update_transactions, tags: batch_tags)

    head :no_content
  end

  # POST /api/v1/transactions/batch_clear_tags
  def batch_clear_tags
    authorize Transaction
    TransactionBatchTagClearer.new.clear_tags(transactions: batch_update_transactions)

    head :no_content
  end

  private

  def filter_params
    params.permit(:transaction_kind, :account_id, :transaction_category_id, :tag_id)
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

  def batch_delete_transactions
    transaction_ids.map do |id|
      policy_scope(Transaction).kept.find(Transaction.decode_prefix_id(id) || id)
    end
  end

  def transaction_ids
    Array(params.permit(transaction_ids: [])[:transaction_ids]).reject(&:blank?).map(&:to_s).uniq
  end

  def batch_update_transactions
    transaction_ids.map do |id|
      policy_scope(Transaction).kept.find(Transaction.decode_prefix_id(id) || id)
    end
  end

  def batch_update_category_target
    current_user.transaction_categories.kept.find(TransactionCategory.decode_prefix_id(batch_update_category_id) || batch_update_category_id)
  end

  def batch_update_category_id
    params[:transaction_category_id].to_s
  end

  def batch_update_account_target
    current_user.accounts.kept.find(Account.decode_prefix_id(batch_update_account_id) || batch_update_account_id)
  end

  def batch_update_account_id
    params[:account_id].to_s
  end

  def batch_update_destination_account?
    ActiveModel::Type::Boolean.new.cast(params[:is_destination_account])
  end

  def batch_tags
    batch_transaction_tag_ids.map do |id|
      current_user.transaction_tags.kept.find(TransactionTag.decode_prefix_id(id) || id)
    end
  end

  def batch_transaction_tag_ids
    Array(params.permit(transaction_tag_ids: [])[:transaction_tag_ids]).reject(&:blank?).map(&:to_s).uniq
  end
end
