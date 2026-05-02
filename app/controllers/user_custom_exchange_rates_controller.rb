class UserCustomExchangeRatesController < ApplicationController
  before_action :authenticate_user!

  # GET /user_custom_exchange_rates
  def index
    authorize UserCustomExchangeRate
    @user_custom_exchange_rate = current_user.user_custom_exchange_rates.build
    load_exchange_rates
  end

  # POST /user_custom_exchange_rates
  def create
    authorize UserCustomExchangeRate
    result = UserCustomExchangeRateSaver.new.save_rate(user: current_user, attributes: user_custom_exchange_rate_params)

    if result.saved?
      redirect_to user_custom_exchange_rates_path, notice: "Exchange rate saved."
    else
      @user_custom_exchange_rate = result.exchange_rate
      load_exchange_rates
      render :index, status: :unprocessable_content
    end
  end

  # DELETE /user_custom_exchange_rates/:id
  def destroy
    exchange_rate = policy_scope(UserCustomExchangeRate).kept.find(params[:id])
    authorize exchange_rate
    exchange_rate.discard!

    redirect_to user_custom_exchange_rates_path, notice: "Exchange rate deleted."
  end

  private

  def user_custom_exchange_rate_params
    params.expect(user_custom_exchange_rate: [ :currency_code, :rate ])
  end

  def load_exchange_rates
    @exchange_rates = policy_scope(UserCustomExchangeRate).kept.order(:currency_code)
    @default_currency_code = current_user.user_preference&.default_currency_code || "USD"
  end
end
