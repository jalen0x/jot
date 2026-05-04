class Api::V1::TransactionsController < ApiController
  # GET /api/v1/transactions
  def index
    authorize Transaction
    transactions = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params)

    render json: { transactions: transactions.map(&:as_json) }
  end

  # GET /api/v1/transactions/count
  def count
    authorize Transaction
    count = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params).count

    render json: { count: count }
  end

  # GET /api/v1/transactions/statistics
  def statistics
    authorize Transaction
    summary = LedgerStatistics.new.summarize_transactions(user: current_user, range: statistics_range, filters: filter_params)

    render json: { statistics: statistics_json(summary) }
  rescue Date::Error
    render json: { errors: [ "Start date and end date must be valid ISO 8601 dates" ] }, status: :unprocessable_content
  end

  # GET /api/v1/transactions/trends
  def trends
    authorize Transaction
    trends = LedgerTrends.new.build_transaction_trends(user: current_user, range: statistics_range, aggregation: trends_aggregation, filters: filter_params)

    render json: { trends: trends_json(trends) }
  rescue Date::Error
    render json: { errors: [ "Start date and end date must be valid ISO 8601 dates" ] }, status: :unprocessable_content
  rescue ArgumentError
    render json: { errors: [ "Aggregation must be day or month" ] }, status: :unprocessable_content
  end

  # GET /api/v1/transactions/:id
  def show
    transaction = scoped_transaction
    authorize transaction

    render json: { transaction: transaction.as_json }
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

  # POST /api/v1/transactions/move_between_accounts
  def move_between_accounts
    authorize Transaction
    result = TransactionAccountMover.new.move_between_accounts(
      user: current_user,
      from_account: move_from_account,
      to_account: move_to_account
    )

    if result.moved?
      head :no_content
    else
      render json: { errors: result.errors }, status: :unprocessable_content
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

  def statistics_range
    start_date = parsed_date(params[:start_date]) || Time.zone.today.beginning_of_month
    end_date = parsed_date(params[:end_date]) || Time.zone.today.end_of_month

    start_date.beginning_of_day..end_date.end_of_day
  end

  def parsed_date(value)
    return if value.blank?

    Date.iso8601(value)
  end

  def statistics_json(summary)
    {
      income_cents: summary.income_cents,
      expense_cents: summary.expense_cents,
      net_cents: summary.net_cents,
      category_totals: summary.category_totals,
      account_totals: summary.account_totals
    }
  end

  def trends_aggregation
    params[:aggregation].presence || "day"
  end

  def trends_json(trends)
    {
      aggregation: trends.aggregation,
      buckets: trends.buckets.map do |bucket|
        {
          starts_on: bucket.starts_on.iso8601,
          income_cents: bucket.income_cents,
          expense_cents: bucket.expense_cents,
          net_cents: bucket.net_cents
        }
      end
    }
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

  def move_from_account
    current_user.accounts.kept.find(Account.decode_prefix_id(move_from_account_id) || move_from_account_id)
  end

  def move_from_account_id
    params[:from_account_id].to_s
  end

  def move_to_account
    current_user.accounts.kept.find(Account.decode_prefix_id(move_to_account_id) || move_to_account_id)
  end

  def move_to_account_id
    params[:to_account_id].to_s
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
