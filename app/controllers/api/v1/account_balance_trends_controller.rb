class Api::V1::AccountBalanceTrendsController < ApiController
  # GET /api/v1/account_balance_trends
  def index
    authorize :account_balance_trend
    trends = AccountBalanceTrends.new.build_account_balance_trends(user: current_user, range: trends_range)

    render json: { account_balance_trends: trends }
  rescue Date::Error
    render json: { errors: [ "Start date and end date must be valid ISO 8601 dates" ] }, status: :unprocessable_content
  end

  private

  def trends_range
    start_date = parsed_date(params[:start_date]) || Time.zone.today.beginning_of_month
    end_date = parsed_date(params[:end_date]) || Time.zone.today.end_of_month

    start_date.beginning_of_day..end_date.end_of_day
  end

  def parsed_date(value)
    return if value.blank?

    Date.iso8601(value)
  end
end
