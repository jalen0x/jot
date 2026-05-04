class Api::V1::TwoFactorRecoveryCodesController < ApiController
  # POST /api/v1/two_factor_recovery_codes
  def create
    two_factor_authentication = current_user.two_factor_authentication

    if two_factor_authentication.blank?
      render_unprocessable("Enable two-factor authentication first.")
      return
    end

    authorize two_factor_authentication, :show?

    unless current_user.valid_password?(two_factor_recovery_codes_params[:current_password])
      render_unprocessable("Current password is incorrect.")
      return
    end

    recovery_codes = TwoFactorRecoveryCodeGenerator.new.generate_for(user: current_user)

    render json: { two_factor_recovery_codes: recovery_codes }, status: :created
  end

  private

  def two_factor_recovery_codes_params
    params.expect(two_factor_recovery_codes: [ :current_password ])
  end

  def render_unprocessable(message)
    render json: { errors: [ message ] }, status: :unprocessable_content
  end
end
