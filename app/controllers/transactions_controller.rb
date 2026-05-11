class TransactionsController < ApplicationController
  before_action :authenticate_user!

  # GET /transactions
  def index
    authorize Transaction
    scope = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params)
    @pagy, @transactions = pagy(:offset, scope)
    @amount_format_options = amount_format_options
    @transaction_datetime_format = transaction_datetime_format
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
    result = TransactionRecorder.new.record_transaction(user: current_user, attributes: transaction_params, tag_ids: transaction_tag_ids, picture_files: picture_files)

    if result.recorded?
      redirect_to post_save_destination, notice: "Transaction recorded."
    else
      @transaction = result.transaction
      load_form_collections
      render :new, status: :unprocessable_content
    end
  end

  # GET /transactions/:id/edit
  def edit
    @transaction = scoped_transaction
    authorize @transaction
    load_form_collections
  end

  # PATCH/PUT /transactions/:id
  def update
    transaction = scoped_transaction
    authorize transaction
    result = TransactionUpdater.new.update_transaction(transaction: transaction, attributes: transaction_params, tag_ids: transaction_tag_ids)

    if result.updated?
      redirect_to transactions_path, notice: "Transaction updated."
    else
      @transaction = result.transaction
      load_form_collections
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /transactions/:id
  def destroy
    transaction = scoped_transaction
    authorize transaction
    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    if result.deleted?
      redirect_to transactions_path, notice: "Transaction deleted.", status: :see_other
    else
      redirect_to transactions_path, alert: result.transaction.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def filter_params
    ledger_filter_params
  end

  def post_save_destination
    case params[:after_save]
    when "new" then new_transaction_path
    else transactions_path
    end
  end

  def transaction_params
    permitted = params.expect(transaction: [
      :transaction_kind,
      :account_id,
      :destination_account_id,
      :transaction_category_id,
      :transacted_at,
      :timezone_utc_offset_minutes,
      :source_amount,
      :destination_amount,
      :hide_amount,
      :comment,
      :geo_latitude,
      :geo_longitude,
      transaction_tag_ids: [],
      pictures: []
    ])

    permitted[:source_amount_cents] = cents_from(permitted.delete(:source_amount)) if permitted.key?(:source_amount)
    permitted[:destination_amount_cents] = cents_from(permitted.delete(:destination_amount)) if permitted.key?(:destination_amount)

    permitted
  end

  def cents_from(amount_str)
    return 0 if amount_str.blank?
    (BigDecimal(amount_str.to_s) * 100).to_i
  rescue ArgumentError
    0
  end

  def transaction_tag_ids
    Array(transaction_params[:transaction_tag_ids]).reject(&:blank?)
  end

  def picture_files
    Array(transaction_params[:pictures]).reject(&:blank?)
  end

  def scoped_transaction
    policy_scope(Transaction).kept.find(params[:id])
  end

  def default_transaction_attributes
    attributes = {
      transaction_kind: :expense,
      transacted_at: Time.current.change(sec: 0),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 0,
      destination_amount_cents: 0
    }
    attributes[:account] = default_account if default_account.present?
    attributes
  end

  def load_form_collections
    @accounts = current_user.accounts.kept.order(:display_order, :name)
    @transaction_categories = current_user.transaction_categories.kept.includes(:parent_category).order(:category_type, :display_order, :name)
    @transaction_tags = current_user.transaction_tags.kept.order(:display_order, :name)
  end

  def load_filter_collections
    @filter_accounts = current_user.accounts.kept.order(:display_order, :name)
    @filter_categories = current_user.transaction_categories.kept.order(:category_type, :display_order, :name)
    @filter_tags = current_user.transaction_tags.kept.order(:display_order, :name)
  end

  def transaction_datetime_format
    current_user.user_preference&.datetime_format || UserPreference.datetime_format_for(UserPreference::DEFAULT_DATE_FORMAT)
  end

  def amount_format_options
    current_user.user_preference&.number_format_options || UserPreference.number_format_options_for(UserPreference::DEFAULT_NUMBER_FORMAT)
  end

  def default_account
    current_user.accounts.kept.find_by(id: current_user.user_preference&.default_account_id)
  end
end
