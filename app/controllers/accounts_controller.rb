class AccountsController < ApplicationController
  before_action :authenticate_user!

  # GET /accounts
  def index
    authorize Account
    @accounts = policy_scope(Account).kept.where(parent_account_id: nil).order(:display_order, :name)
    @sub_accounts_by_parent_id = policy_scope(Account).kept
      .where(parent_account_id: @accounts.select(:id))
      .order(:display_order, :name)
      .group_by(&:parent_account_id)
  end

  # GET /accounts/new
  def new
    @account = current_user.accounts.build(default_account_attributes)
    @parent_account_options = parent_account_options
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
      @parent_account_options = parent_account_options
      render :new, status: :unprocessable_content
    end
  end

  # GET /accounts/:id/edit
  def edit
    @account = scoped_account
    @parent_account_options = parent_account_options(excluding: @account)
    authorize @account
  end

  # PATCH/PUT /accounts/:id
  def update
    account = scoped_account
    authorize account
    update_params = account_update_params
    account.assign_attributes(update_params.except(:parent_account_id))
    assign_parent_account(account, update_params[:parent_account_id]) if update_params.key?(:parent_account_id)

    if account.errors.empty? && account.save
      redirect_to accounts_path, notice: "Account updated."
    else
      @account = account
      @parent_account_options = parent_account_options(excluding: account)
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /accounts/:id
  def destroy
    account = scoped_account
    authorize account
    account.discard!

    redirect_to accounts_path, notice: "Account deleted.", status: :see_other
  end

  private

  def account_attributes
    account_params.except(:opening_balance_cents, :parent_account_id).merge(
      parent_account: parent_account,
      display_order: next_display_order(parent_account)
    )
  end

  def account_params
    params.expect(account: [
      :name,
      :account_category,
      :account_structure,
      :icon_key,
      :color_hex,
      :currency_code,
      :parent_account_id,
      :opening_balance_cents,
      :hidden,
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
      :parent_account_id,
      :hidden,
      :comment
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

  def assign_parent_account(account, parent_account_id)
    account.parent_account = resolved_parent_account(account, parent_account_id)
  end

  def resolved_parent_account(account, parent_account_id)
    return if parent_account_id.blank?

    parent_account = current_user.accounts.kept.find(Account.decode_prefix_id(parent_account_id) || parent_account_id)
    return parent_account unless parent_account == account

    account.errors.add(:parent_account, "cannot be itself")
    nil
  rescue ActiveRecord::RecordNotFound
    account.errors.add(:parent_account, "is unavailable")
    nil
  end

  def scoped_account
    policy_scope(Account).kept.find(params[:id])
  end

  def next_display_order(parent_account = nil)
    current_user.accounts.kept.where(parent_account: parent_account).maximum(:display_order).to_i + 1
  end

  def parent_account_options(excluding: nil)
    scope = current_user.accounts.kept.order(:display_order, :name)
    scope = scope.where.not(id: excluding.id) if excluding
    scope
  end

  def default_account_attributes
    {
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: default_currency_code,
      balance_cents: 0,
      hidden: false,
      display_order: next_display_order
    }
  end

  def default_currency_code
    current_user.user_preference&.default_currency_code || "USD"
  end
end
