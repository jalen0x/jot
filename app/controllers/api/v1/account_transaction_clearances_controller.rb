class Api::V1::AccountTransactionClearancesController < ApiController
  # POST /api/v1/accounts/:account_id/transaction_clearance
  def create
    authorize :account_transaction_clearance
    account = scoped_account
    permitted = account_transaction_clearance_params

    unless current_user.valid_password?(permitted[:current_password])
      render json: { errors: [ "Current password is incorrect" ] }, status: :unprocessable_content
      return
    end

    result = LedgerClearance.new.clear_account_transactions(user: current_user, account: account)
    if result.cleared?
      render json: { account_transaction_clearance: { account_id: account.to_param } }, status: :created
    else
      render json: { errors: result.errors }, status: :unprocessable_content
    end
  end

  private

  def account_transaction_clearance_params
    params.expect(account_transaction_clearance: [ :current_password ])
  end

  def scoped_account
    current_user.accounts.kept.find(Account.decode_prefix_id(params[:account_id]) || params[:account_id])
  end
end
