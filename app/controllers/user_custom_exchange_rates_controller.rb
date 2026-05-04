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

  # GET /user_custom_exchange_rates/:id/edit
  def edit
    @user_custom_exchange_rate = scoped_exchange_rate
    authorize @user_custom_exchange_rate
    load_default_currency_code
  end

  # PATCH/PUT /user_custom_exchange_rates/:id
  def update
    @user_custom_exchange_rate = scoped_exchange_rate
    authorize @user_custom_exchange_rate

    if @user_custom_exchange_rate.update(user_custom_exchange_rate_params)
      redirect_to user_custom_exchange_rates_path, notice: t(".updated")
    else
      load_default_currency_code
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /user_custom_exchange_rates/:id
  def destroy
    exchange_rate = scoped_exchange_rate
    authorize exchange_rate
    exchange_rate.discard!

    redirect_to user_custom_exchange_rates_path, notice: "Exchange rate deleted.", status: :see_other
  end

  private

  def user_custom_exchange_rate_params
    params.expect(user_custom_exchange_rate: [ :currency_code, :rate ])
  end

  def load_exchange_rates
    @exchange_rates = policy_scope(UserCustomExchangeRate).kept.order(:currency_code)
    load_default_currency_code
  end

  def load_default_currency_code
    @default_currency_code = current_user.user_preference&.default_currency_code || "USD"
  end

  def scoped_exchange_rate
    policy_scope(UserCustomExchangeRate).kept.find(params[:id])
  end
end
