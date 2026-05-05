class Api::V1::TransactionTrendsController < ApiController
  # GET /api/v1/transaction_trends
  def index
    authorize :transaction_trend
    trends = LedgerTrends.new.build_transaction_trends(
      user: current_user,
      range: trends_range,
      aggregation: trends_aggregation,
      filters: filter_params
    )

    render json: { trends: trends }
  rescue Date::Error
    render json: { errors: [ "Start date and end date must be valid ISO 8601 dates" ] }, status: :unprocessable_content
  rescue ArgumentError
    render json: { errors: [ "Aggregation must be day or month" ] }, status: :unprocessable_content
  end

  private

  def filter_params
    ledger_filter_params(include_amounts: true)
  end

  def trends_range
    start_date = parsed_date(params[:start_date]) || Time.zone.today.beginning_of_month
    end_date = parsed_date(params[:end_date]) || Time.zone.today.end_of_month

    start_date.beginning_of_day..end_date.end_of_day
  end

  def parsed_date(value)
    return if value.blank?

    Date.iso8601(value)
  end

  def trends_aggregation
    params[:aggregation].presence || "day"
  end
end
