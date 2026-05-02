class DashboardsController < ApplicationController
  before_action :authenticate_user!

  # GET /dashboard
  def show
    authorize :dashboard
    @summary = DashboardSummary.new.summarize(user: current_user)
  end
end
