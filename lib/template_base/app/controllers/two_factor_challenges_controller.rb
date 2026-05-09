class TwoFactorChallengesController < ApplicationController
  include Devise::Controllers::Rememberable

  before_action :load_pending_user
  before_action :enforce_login_rate_limit, only: :create

  # GET /two_factor_challenge/new
  def new
  end

  # POST /two_factor_challenge
  def create
    result = TwoFactorChallengeVerifier.new.verify(user: @pending_user, code: two_factor_challenge_params[:otp_code])

    if result.verified?
      complete_pending_sign_in
      redirect_to after_sign_in_path_for(@pending_user), notice: t(".success")
    else
      login_attempt_limiter.record_failure(email: @pending_user.email, ip: request.remote_ip)
      @error_message = t(".invalid_otp")
      render :new, status: :unprocessable_content
    end
  end

  private

  def load_pending_user
    @pending_user = User.find_by(id: session[:pending_two_factor_user_id])
    return if @pending_user&.two_factor_enabled?

    session.delete(:pending_two_factor_user_id)
    session.delete(:pending_two_factor_remember_me)
    redirect_to new_user_session_path, alert: t(".missing_challenge")
  end

  def enforce_login_rate_limit
    return unless login_attempt_limiter.blocked?(email: @pending_user.email, ip: request.remote_ip)

    flash.now[:alert] = t("users.sessions.create.too_many_attempts")
    render :new, status: :too_many_requests
  end

  def complete_pending_sign_in
    remember_me_enabled = session.delete(:pending_two_factor_remember_me)
    session.delete(:pending_two_factor_user_id)
    remember_me(@pending_user) if remember_me_enabled
    sign_in(:user, @pending_user)
    login_attempt_limiter.reset(email: @pending_user.email, ip: request.remote_ip)
  end

  def login_attempt_limiter
    @login_attempt_limiter ||= LoginAttemptLimiter.new
  end

  def two_factor_challenge_params
    params.expect(two_factor_challenge: [ :otp_code ])
  end
end
