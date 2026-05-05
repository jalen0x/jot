class Api::V1::DataStatisticsController < ApiController
  # GET /api/v1/data_statistics
  def show
    authorize :data_statistics
    statistics = DataStatistics.new.summarize_user_data(user: current_user)

    render json: { data_statistics: statistics }
  end
end
