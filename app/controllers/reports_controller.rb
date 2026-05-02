class ReportsController < ApplicationController
  before_action :authenticate_user!

  # GET /reports
  def show
    authorize :report
    @start_date = parse_date(params[:start_date]) || Time.zone.today.beginning_of_month
    @end_date = parse_date(params[:end_date]) || Time.zone.today.end_of_month
    @summary = LedgerStatistics.new.summarize_transactions(user: current_user, range: @start_date.beginning_of_day..@end_date.end_of_day)
  end

  private

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    nil
  end
end
