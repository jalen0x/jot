class Api::V1::ExchangeRateCatalogsController < ApiController
  # GET /api/v1/exchange_rate_catalog
  def show
    authorize ExchangeRateCatalog
    catalog = ExchangeRateCatalog.new.latest_rates(user: current_user)

    render json: { exchange_rate_catalog: catalog }
  end
end
