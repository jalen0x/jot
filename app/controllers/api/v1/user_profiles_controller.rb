class Api::V1::UserProfilesController < ApiController
  # GET /api/v1/user_profile
  def show
    authorize :user_profile

    render json: { user_profile: user_profile }
  end

  # PATCH/PUT /api/v1/user_profile
  def update
    authorize :user_profile

    if user_profile.update(user_profile_params)
      render json: { user_profile: user_profile }
    else
      render json: { errors: user_profile.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def user_profile
    @user_profile ||= UserProfile.new(current_user)
  end

  def user_profile_params
    params.expect(user_profile: [ :first_name, :last_name ])
  end
end
