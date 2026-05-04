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
    account_params.except(:opening_balance_cents).merge(display_order: next_display_order)
  end

  def account_params
    @account_params ||= params.expect(account: [
      :name,
      :account_category,
      :account_structure,
      :icon_key,
      :color_hex,
      :currency_code,
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

  def next_display_order
    current_user.accounts.kept.where(parent_account_id: nil).maximum(:display_order).to_i + 1
  end

  def scoped_account
    policy_scope(Account).kept.find(params[:id])
  end
end
