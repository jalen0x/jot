class TwoFactorAuthenticationsController < ApplicationController
  before_action :authenticate_user!

  # GET /two_factor_authentication
  def show
    authorize TwoFactorAuthentication
    load_two_factor_authentication
    prepare_setup unless @two_factor_authentication
  end

  # POST /two_factor_authentication
  def create
    authorize TwoFactorAuthentication
    load_two_factor_authentication

    if @two_factor_authentication
      redirect_to two_factor_authentication_path, notice: "Two-factor authentication is already enabled."
      return
    end

    permitted = two_factor_authentication_params

    unless current_user.valid_password?(permitted[:current_password])
      render_setup_error("Current password is incorrect.")
      return
    end

    unless setup_authentication.verify_otp(permitted[:otp_code])
      render_setup_error("Verification code is invalid.")
      return
    end

    @recovery_codes = TwoFactorAuthenticationEnabler.new.enable(
      user: current_user,
      otp_secret: session[:pending_two_factor_secret]
    )
    session.delete(:pending_two_factor_secret)
    load_two_factor_authentication
    flash.now[:notice] = "Two-factor authentication enabled."

    render :show, status: :created
  end

  # DELETE /two_factor_authentication
  def destroy
    load_two_factor_authentication

    unless @two_factor_authentication
      redirect_to two_factor_authentication_path, notice: "Two-factor authentication is not enabled."
      return
    end

    authorize @two_factor_authentication

    unless current_user.valid_password?(two_factor_authentication_params[:current_password])
      @error_message = "Current password is incorrect."
      render :show, status: :unprocessable_content
      return
    end

    TwoFactorAuthentication.transaction do
      current_user.two_factor_recovery_codes.destroy_all
      @two_factor_authentication.destroy!
    end

    redirect_to two_factor_authentication_path, notice: "Two-factor authentication disabled."
  end

  private

  def load_two_factor_authentication
    @two_factor_authentication = current_user.two_factor_authentication
  end

  def prepare_setup
    @setup_secret = session[:pending_two_factor_secret] ||= TwoFactorAuthentication.generate_secret
    @provisioning_uri = setup_authentication.provisioning_uri
  end

  def setup_authentication
    current_user.build_two_factor_authentication(
      otp_secret: session[:pending_two_factor_secret],
      enabled_at: Time.current
    )
  end

  def render_setup_error(message)
    @error_message = message
    prepare_setup
    render :show, status: :unprocessable_content
  end

  def two_factor_authentication_params
    params.expect(two_factor_authentication: [ :current_password, :otp_code ])
  end
end
