class Api::V1::TwoFactorSetupsController < ApiController
  # POST /api/v1/two_factor_setup
  def create
    authorize TwoFactorAuthentication, :create?
    permitted = two_factor_setup_params

    if current_user.two_factor_enabled?
      render_unprocessable("Two-factor authentication is already enabled.")
    elsif !current_user.valid_password?(permitted[:current_password])
      render_unprocessable("Current password is incorrect.")
    else
      otp_secret = TwoFactorAuthentication.generate_secret
      setup_authentication = TwoFactorAuthentication.new(user: current_user, otp_secret: otp_secret, enabled_at: Time.current)
      render json: { two_factor_setup: { otp_secret: otp_secret, provisioning_uri: setup_authentication.provisioning_uri } }, status: :created
    end
  end

  private

  def two_factor_setup_params
    params.expect(two_factor_setup: [ :current_password ])
  end

  def render_unprocessable(message)
    render json: { errors: [ message ] }, status: :unprocessable_content
  end
end
