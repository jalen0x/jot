class Api::V1::UserPreferencesController < ApiController
  # GET /api/v1/user_preference
  def show
    authorize :user_preference

    render json: { user_preference: user_preference.as_json }
  end

  # PATCH/PUT /api/v1/user_preference
  def update
    authorize :user_preference

    if user_preference.update(user_preference_params)
      render json: { user_preference: user_preference.as_json }
    else
      render json: { errors: user_preference.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def user_preference
    @user_preference ||= current_user.user_preference || current_user.build_user_preference(default_currency_code: "USD")
  end

  def user_preference_params
    params.expect(user_preference: [ :default_currency_code ])
  end
end
