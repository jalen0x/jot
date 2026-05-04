class UserProfilesController < ApplicationController
  before_action :authenticate_user!

  # GET /user_profile
  def show
    authorize :user_profile
    @user_profile = UserProfile.new(current_user)
  end

  # PATCH /user_profile
  def update
    authorize :user_profile
    @user_profile = UserProfile.new(current_user)

    if @user_profile.update(user_profile_params)
      redirect_to user_profile_path, notice: t(".updated")
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def user_profile_params
    params.expect(user_profile: [ :first_name, :last_name ])
  end
end
