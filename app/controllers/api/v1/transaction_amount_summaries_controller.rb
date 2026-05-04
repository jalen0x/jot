class Api::V1::TransactionAmountSummariesController < ApiController
  # GET /api/v1/transaction_amount_summary
  def show
    authorize :transaction_amount_summary
    summary = TransactionAmountSummary.new.summarize_transactions(user: current_user, range: summary_range)

    render json: { transaction_amount_summary: summary_json(summary) }
  rescue Date::Error
    render json: { errors: [ "Start date and end date must be valid ISO 8601 dates" ] }, status: :unprocessable_content
  end

  private

  def summary_range
    start_date = parsed_date(params[:start_date]) || Time.zone.today.beginning_of_month
    end_date = parsed_date(params[:end_date]) || Time.zone.today.end_of_month

    start_date.beginning_of_day..end_date.end_of_day
  end

  def parsed_date(value)
    return if value.blank?

    Date.iso8601(value)
  end

  def summary_json(summary)
    {
      amounts: summary.amounts.map do |amount|
        {
          currency_code: amount.currency_code,
          income_cents: amount.income_cents,
          expense_cents: amount.expense_cents,
          net_cents: amount.net_cents
        }
      end
    }
  end
end
