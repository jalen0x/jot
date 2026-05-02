class TransactionsController < ApplicationController
  before_action :authenticate_user!

  # GET /transactions
  def index
    authorize Transaction
    @transactions = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params)
    load_filter_collections
  end

  # GET /transactions/new
  def new
    @transaction = current_user.transactions.build(default_transaction_attributes)
    authorize @transaction
    load_form_collections
  end

  # POST /transactions
  def create
    authorize Transaction
    result = TransactionRecorder.new.record_transaction(user: current_user, attributes: transaction_params, tag_ids: transaction_tag_ids)

    if result.recorded?
      redirect_to transactions_path, notice: "Transaction recorded."
    else
      @transaction = result.transaction
      load_form_collections
      render :new, status: :unprocessable_content
    end
  end

  # DELETE /transactions/:id
  def destroy
    transaction = policy_scope(Transaction).kept.find(params[:id])
    authorize transaction
    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    if result.deleted?
      redirect_to transactions_path, notice: "Transaction deleted."
    else
      redirect_to transactions_path, alert: result.transaction.errors.full_messages.to_sentence
    end
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
      transaction_tag_ids: []
    ])
  end

  def transaction_tag_ids
    Array(transaction_params[:transaction_tag_ids]).reject(&:blank?)
  end

  def default_transaction_attributes
    {
      transaction_kind: :expense,
      transacted_at: Time.current.change(sec: 0),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 0,
      destination_amount_cents: 0
    }
  end

  def load_form_collections
    @accounts = current_user.accounts.kept.order(:display_order, :name)
    @transaction_categories = current_user.transaction_categories.kept.order(:category_type, :display_order, :name)
    @transaction_tags = current_user.transaction_tags.kept.order(:display_order, :name)
  end

  def load_filter_collections
    @filter_accounts = current_user.accounts.kept.order(:display_order, :name)
    @filter_categories = current_user.transaction_categories.kept.order(:category_type, :display_order, :name)
    @filter_tags = current_user.transaction_tags.kept.order(:display_order, :name)
  end
end
