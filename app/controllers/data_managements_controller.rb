class DataManagementsController < ApplicationController
  before_action :authenticate_user!

  # GET /data_management
  def show
    authorize :data_management
    @statistics = DataStatistics.new.summarize_user_data(user: current_user)
  end
end
