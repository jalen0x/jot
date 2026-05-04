class Api::V1::AccountReconciliationStatementsController < ApiController
  # GET /api/v1/accounts/:account_id/reconciliation_statement
  def show
    authorize :account_reconciliation_statement
    statement = AccountReconciliation.new.build_statement(account: account, range: statement_range)

    render json: { reconciliation_statement: statement_json(statement) }
  rescue Date::Error
    render json: { errors: [ "Start date and end date must be valid ISO 8601 dates" ] }, status: :unprocessable_content
  end

  private

  def account
    @account ||= current_user.accounts.kept.find(Account.decode_prefix_id(account_id) || account_id)
  end

  def account_id
    params[:account_id].to_s
  end

  def statement_range
    start_date = parsed_date(params[:start_date]) || Time.zone.today.beginning_of_month
    end_date = parsed_date(params[:end_date]) || Time.zone.today.end_of_month

    start_date.beginning_of_day..end_date.end_of_day
  end

  def parsed_date(value)
    return if value.blank?

    Date.iso8601(value)
  end

  def statement_json(statement)
    {
      account_id: statement.account.to_param,
      start_date: statement.range.begin.to_date.iso8601,
      end_date: statement.range.end.to_date.iso8601,
      opening_balance_cents: statement.opening_balance_cents,
      inflow_cents: statement.inflow_cents,
      outflow_cents: statement.outflow_cents,
      closing_balance_cents: statement.closing_balance_cents,
      transaction_ids: statement.transactions.map(&:to_param)
    }
  end
end
