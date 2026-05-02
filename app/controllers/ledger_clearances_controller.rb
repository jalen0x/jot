class LedgerClearancesController < ApplicationController
  before_action :authenticate_user!

  # GET /ledger_clearance/new
  def new
    authorize :ledger_clearance
    load_counts
  end

  # POST /ledger_clearance
  def create
    authorize :ledger_clearance
    permitted = ledger_clearance_params

    unless current_user.valid_password?(permitted[:current_password])
      @ledger_clearance_error = "Current password is incorrect."
      load_counts
      render :new, status: :unprocessable_content
      return
    end

    case permitted[:clearance_scope]
    when "transactions"
      LedgerClearance.new.clear_transactions(user: current_user)
      redirect_to new_ledger_clearance_path, notice: "Transactions cleared."
    when "all"
      LedgerClearance.new.clear_all_data(user: current_user)
      redirect_to new_ledger_clearance_path, notice: "Ledger data cleared."
    else
      @ledger_clearance_error = "Choose what to clear."
      load_counts
      render :new, status: :unprocessable_content
    end
  end

  private

  def ledger_clearance_params
    params.expect(ledger_clearance: [ :clearance_scope, :current_password ])
  end

  def load_counts
    @ledger_counts = {
      accounts: current_user.accounts.kept.count,
      transaction_categories: current_user.transaction_categories.kept.count,
      transaction_tags: current_user.transaction_tags.kept.count,
      transactions: current_user.transactions.kept.count
    }
  end
end
