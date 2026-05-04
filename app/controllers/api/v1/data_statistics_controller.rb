class Api::V1::DataStatisticsController < ApiController
  # GET /api/v1/data_statistics
  def show
    authorize :data_statistics
    statistics = DataStatistics.new.summarize_user_data(user: current_user)

    render json: { data_statistics: statistics_json(statistics) }
  end

  private

  def statistics_json(statistics)
    {
      account_count: statistics.account_count,
      transaction_category_count: statistics.transaction_category_count,
      transaction_tag_count: statistics.transaction_tag_count,
      transaction_count: statistics.transaction_count,
      transaction_picture_count: statistics.transaction_picture_count,
      insight_explorer_count: statistics.insight_explorer_count,
      transaction_template_count: statistics.transaction_template_count,
      scheduled_transaction_count: statistics.scheduled_transaction_count
    }
  end
end
