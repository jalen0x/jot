class TwoFactorRecoveryCodesController < ApplicationController
  before_action :authenticate_user!

  # POST /two_factor_recovery_codes
  def create
    @two_factor_authentication = current_user.two_factor_authentication

    unless @two_factor_authentication
      redirect_to two_factor_authentication_path, alert: t(".not_enabled")
      return
    end

    authorize @two_factor_authentication, :show?

    unless current_user.valid_password?(two_factor_recovery_codes_params[:current_password])
      @error_message = t(".invalid_password")
      render "two_factor_authentications/show", status: :unprocessable_content
      return
    end

    @recovery_codes = TwoFactorRecoveryCodeGenerator.new.generate_for(user: current_user)

    render "two_factor_authentications/show", status: :created
  end

  private

  def two_factor_recovery_codes_params
    params.expect(two_factor_recovery_codes: [ :current_password ])
  end
end
