class Api::V1::TwoFactorAuthenticationsController < ApiController
  # GET /api/v1/two_factor_authentication
  def show
    authorize TwoFactorAuthentication

    render json: { two_factor_authentication: current_user.two_factor_authentication || { enabled: false } }
  end

  # POST /api/v1/two_factor_authentication
  def create
    authorize TwoFactorAuthentication
    permitted = two_factor_authentication_params

    if current_user.two_factor_enabled?
      render_unprocessable("Two-factor authentication is already enabled.")
    elsif !current_user.valid_password?(permitted[:current_password])
      render_unprocessable("Current password is incorrect.")
    elsif permitted[:otp_secret].blank?
      render_unprocessable("OTP secret is required.")
    elsif !setup_authentication(permitted[:otp_secret]).verify_otp(permitted[:otp_code])
      render_unprocessable("Verification code is invalid.")
    else
      result = TwoFactorAuthenticationEnabler.new.enable(
        user: current_user,
        current_password: permitted[:current_password],
        otp_code: permitted[:otp_code],
        otp_secret: permitted[:otp_secret]
      )
      render json: {
        two_factor_authentication: current_user.reload.two_factor_authentication,
        two_factor_recovery_codes: result.recovery_codes
      }, status: :created
    end
  end

  # DELETE /api/v1/two_factor_authentication
  def destroy
    two_factor_authentication = current_user.two_factor_authentication

    if two_factor_authentication.blank?
      render_unprocessable("Two-factor authentication is not enabled.")
      return
    end

    authorize two_factor_authentication

    unless current_user.valid_password?(two_factor_authentication_params[:current_password])
      render_unprocessable("Current password is incorrect.")
      return
    end

    TwoFactorAuthentication.transaction do
      current_user.two_factor_recovery_codes.destroy_all
      two_factor_authentication.destroy!
    end

    head :no_content
  end

  private

  def two_factor_authentication_params
    params.expect(two_factor_authentication: [ :current_password, :otp_secret, :otp_code ])
  end

  def setup_authentication(otp_secret)
    TwoFactorAuthentication.new(user: current_user, otp_secret: otp_secret, enabled_at: Time.current)
  end

  def render_unprocessable(message)
    render json: { errors: [ message ] }, status: :unprocessable_content
  end
end
