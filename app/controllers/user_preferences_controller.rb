class UserPreferencesController < ApplicationController
  before_action :authenticate_user!

  # GET /user_preference
  def show
    authorize :user_preference
    @user_preference = find_or_build_preference
  end

  # PATCH /user_preference
  def update
    authorize :user_preference
    @user_preference = find_or_build_preference

    if @user_preference.update(user_preference_params)
      redirect_to user_preference_path, notice: "Preferences updated."
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def find_or_build_preference
    current_user.user_preference || current_user.build_user_preference(default_currency_code: "USD")
  end

  def user_preference_params
    params.expect(user_preference: [ :default_currency_code ])
  end
end
