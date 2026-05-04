class AccountReconciliationStatementsController < ApplicationController
  before_action :authenticate_user!

  # GET /accounts/:account_id/reconciliation_statement
  def show
    @account = account
    authorize :account_reconciliation_statement
    @start_date, @end_date = statement_dates
    @statement = AccountReconciliation.new.build_statement(account: @account, range: statement_range)
  rescue Date::Error
    @date_error = t(".invalid_dates")
    @start_date = params[:start_date]
    @end_date = params[:end_date]
    render :show, status: :unprocessable_content
  end

  private

  def account
    @account ||= policy_scope(Account).kept.find(params[:account_id])
  end

  def statement_dates
    [
      parsed_date(params[:start_date]) || Time.zone.today.beginning_of_month,
      parsed_date(params[:end_date]) || Time.zone.today.end_of_month
    ]
  end

  def statement_range
    @start_date.beginning_of_day..@end_date.end_of_day
  end

  def parsed_date(value)
    return if value.blank?

    Date.iso8601(value)
  end
end
