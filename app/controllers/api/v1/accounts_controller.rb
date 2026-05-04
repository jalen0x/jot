class Api::V1::AccountsController < ApiController
  # GET /api/v1/accounts
  def index
    authorize Account
    accounts = policy_scope(Account).kept.order(:display_order, :name)

    render json: { accounts: accounts.map(&:as_json) }
  end

  # GET /api/v1/accounts/:id
  def show
    account = scoped_account
    authorize account

    render json: { account: account.as_json }
  end

  # POST /api/v1/accounts
  def create
    authorize Account
    result = AccountCreator.new.create_account(
      user: current_user,
      attributes: account_attributes,
      opening_balance_cents: opening_balance_cents
    )

    if result.created?
      render json: { account: result.account.as_json }, status: :created
    else
      render json: { errors: result.account.errors.full_messages }, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ "Parent account is unavailable" ] }, status: :unprocessable_content
  end

  # PATCH/PUT /api/v1/accounts/:id
  def update
    account = scoped_account
    authorize account

    if account.update(account_update_params)
      render json: { account: account.as_json }
    else
      render json: { errors: account.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/accounts/:id
  def destroy
    account = scoped_account
    authorize account
    account.discard!

    head :no_content
  end

  private

  def account_attributes
    account_params.except(:opening_balance_cents, :parent_account_id).merge(
      parent_account: parent_account,
      display_order: next_display_order(parent_account)
    )
  end

  def account_params
    @account_params ||= params.expect(account: [
      :name,
      :account_category,
      :account_structure,
      :icon_key,
      :color_hex,
      :currency_code,
      :parent_account_id,
      :opening_balance_cents,
      :comment
    ])
  end

  def account_update_params
    params.expect(account: [
      :name,
      :account_category,
      :account_structure,
      :icon_key,
      :color_hex,
      :currency_code,
      :comment,
      :hidden,
      :display_order
    ])
  end

  def opening_balance_cents
    account_params[:opening_balance_cents].to_i
  end

  def parent_account
    return if parent_account_id.blank?

    @parent_account ||= current_user.accounts.kept.find(Account.decode_prefix_id(parent_account_id) || parent_account_id)
  end

  def parent_account_id
    account_params[:parent_account_id].to_s
  end

  def next_display_order(parent_account)
    current_user.accounts.kept.where(parent_account: parent_account).maximum(:display_order).to_i + 1
  end

  def scoped_account
    policy_scope(Account).kept.find(params[:id])
  end
end
