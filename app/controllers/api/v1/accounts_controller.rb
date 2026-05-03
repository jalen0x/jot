class Api::V1::AccountsController < ApiController
  # GET /api/v1/accounts
  def index
    authorize Account
    accounts = policy_scope(Account).kept.order(:display_order, :name)

    render json: { accounts: accounts.map(&:as_json) }
  end
end
