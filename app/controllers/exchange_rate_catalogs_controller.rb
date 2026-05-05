class ExchangeRateCatalogsController < ApplicationController
  before_action :authenticate_user!

  # GET /exchange_rate_catalog
  def show
    authorize ExchangeRateCatalog
    @catalog = ExchangeRateCatalog.new.latest_rates(user: current_user)
  end
end
