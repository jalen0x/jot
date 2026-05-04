class Api::V1::UserCustomExchangeRatesController < ApiController
  # GET /api/v1/user_custom_exchange_rates
  def index
    authorize UserCustomExchangeRate
    exchange_rates = policy_scope(UserCustomExchangeRate).kept.order(:currency_code)

    render json: { user_custom_exchange_rates: exchange_rates.map(&:as_json) }
  end

  # GET /api/v1/user_custom_exchange_rates/:id
  def show
    exchange_rate = scoped_exchange_rate
    authorize exchange_rate

    render json: { user_custom_exchange_rate: exchange_rate }
  end

  # POST /api/v1/user_custom_exchange_rates
  def create
    authorize UserCustomExchangeRate
    exchange_rate = current_user.user_custom_exchange_rates.build(user_custom_exchange_rate_params)

    if exchange_rate.save
      render json: { user_custom_exchange_rate: exchange_rate }, status: :created
    else
      render json: { errors: exchange_rate.errors.full_messages }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/v1/user_custom_exchange_rates/:id
  def update
    exchange_rate = scoped_exchange_rate
    authorize exchange_rate

    if exchange_rate.update(user_custom_exchange_rate_params)
      render json: { user_custom_exchange_rate: exchange_rate }
    else
      render json: { errors: exchange_rate.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/user_custom_exchange_rates/:id
  def destroy
    exchange_rate = scoped_exchange_rate
    authorize exchange_rate
    exchange_rate.discard!

    head :no_content
  end

  private

  def user_custom_exchange_rate_params
    params.expect(user_custom_exchange_rate: [ :currency_code, :rate ])
  end

  def scoped_exchange_rate
    policy_scope(UserCustomExchangeRate).kept.find(params[:id])
  end
end
