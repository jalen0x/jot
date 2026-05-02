class AccountsController < ApplicationController
  before_action :authenticate_user!

  # GET /accounts
  def index
    authorize Account
    @accounts = policy_scope(Account).kept.where(parent_account_id: nil).order(:display_order, :name)
  end

  # GET /accounts/new
  def new
    @account = current_user.accounts.build(default_account_attributes)
    authorize @account
  end

  # POST /accounts
  def create
    authorize Account

    result = AccountCreator.new.create_account(
      user: current_user,
      attributes: account_attributes,
      opening_balance_cents: opening_balance_cents
    )

    if result.created?
      redirect_to accounts_path, notice: "Account created."
    else
      @account = result.account
      render :new, status: :unprocessable_content
    end
  end

  private

  def account_attributes
    account_params.except(:opening_balance_cents).merge(display_order: next_display_order)
  end

  def account_params
    params.expect(account: [
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

  def opening_balance_cents
    account_params[:opening_balance_cents].to_i
  end

  def next_display_order
    current_user.accounts.kept.where(parent_account_id: nil).maximum(:display_order).to_i + 1
  end

  def default_account_attributes
    {
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: default_currency_code,
      balance_cents: 0,
      display_order: next_display_order
    }
  end

  def default_currency_code
    current_user.user_preference&.default_currency_code || "USD"
  end
end
