class Api::V1::LedgerClearancesController < ApiController
  # POST /api/v1/ledger_clearances
  def create
    authorize :ledger_clearance
    permitted = ledger_clearance_params

    unless current_user.valid_password?(permitted[:current_password])
      render json: { errors: [ "Current password is incorrect" ] }, status: :unprocessable_content
      return
    end

    case permitted[:clearance_scope]
    when "transactions"
      LedgerClearance.new.clear_transactions(user: current_user)
      render json: { ledger_clearance: { clearance_scope: "transactions" } }, status: :created
    when "all"
      LedgerClearance.new.clear_all_data(user: current_user)
      render json: { ledger_clearance: { clearance_scope: "all" } }, status: :created
    else
      render json: { errors: [ "Clearance scope must be transactions or all" ] }, status: :unprocessable_content
    end
  end

  private

  def ledger_clearance_params
    params.expect(ledger_clearance: [ :clearance_scope, :current_password ])
  end
end
