class TwoFactorChallengesController < ApplicationController
  before_action :load_pending_user

  # GET /two_factor_challenge/new
  def new
  end

  # POST /two_factor_challenge
  def create
    if @pending_user.two_factor_authentication.verify_otp(two_factor_challenge_params[:otp_code])
      session.delete(:pending_two_factor_user_id)
      sign_in(:user, @pending_user)
      redirect_to after_sign_in_path_for(@pending_user), notice: "Signed in successfully."
    else
      @error_message = "Verification code is invalid."
      render :new, status: :unprocessable_content
    end
  end

  private

  def load_pending_user
    @pending_user = User.find_by(id: session[:pending_two_factor_user_id])
    return if @pending_user&.two_factor_enabled?

    session.delete(:pending_two_factor_user_id)
    redirect_to new_user_session_path, alert: "Sign in to continue."
  end

  def two_factor_challenge_params
    params.expect(two_factor_challenge: [ :otp_code ])
  end
end
