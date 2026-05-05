class Api::V1::TransactionStatisticsController < ApiController
  # GET /api/v1/transaction_statistics
  def show
    authorize :transaction_statistics
    summary = LedgerStatistics.new.summarize_transactions(
      user: current_user,
      range: statistics_range,
      filters: filter_params
    )

    render json: { statistics: summary }
  rescue Date::Error
    render json: { errors: [ "Start date and end date must be valid ISO 8601 dates" ] }, status: :unprocessable_content
  end

  private

  def filter_params
    ledger_filter_params(include_amounts: true)
  end

  def statistics_range
    start_date = parsed_date(params[:start_date]) || Time.zone.today.beginning_of_month
    end_date = parsed_date(params[:end_date]) || Time.zone.today.end_of_month

    start_date.beginning_of_day..end_date.end_of_day
  end

  def parsed_date(value)
    return if value.blank?

    Date.iso8601(value)
  end
end
