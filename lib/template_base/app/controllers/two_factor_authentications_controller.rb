class TwoFactorAuthenticationsController < ApplicationController
  before_action :authenticate_user!

  # GET /two_factor_authentication
  def show
    authorize TwoFactorAuthentication
    @two_factor_authentication = current_user.two_factor_authentication
    prepare_setup unless @two_factor_authentication
  end

  # POST /two_factor_authentication
  def create
    authorize TwoFactorAuthentication
    @two_factor_authentication = current_user.two_factor_authentication

    if @two_factor_authentication
      redirect_to two_factor_authentication_path, notice: t(".already_enabled")
      return
    end

    permitted = two_factor_authentication_params

    unless current_user.valid_password?(permitted[:current_password])
      render_setup_error(t(".invalid_password"))
      return
    end

    unless setup_authentication.verify_otp(permitted[:otp_code])
      render_setup_error(t(".invalid_otp"))
      return
    end

    @recovery_codes = TwoFactorAuthenticationEnabler.new.enable(
      user: current_user,
      otp_secret: session[:pending_two_factor_secret]
    )
    session.delete(:pending_two_factor_secret)
    @two_factor_authentication = current_user.two_factor_authentication
    flash.now[:notice] = t(".enabled")

    render :show, status: :created
  end

  # DELETE /two_factor_authentication
  def destroy
    @two_factor_authentication = current_user.two_factor_authentication

    unless @two_factor_authentication
      redirect_to two_factor_authentication_path, notice: t(".not_enabled"), status: :see_other
      return
    end

    authorize @two_factor_authentication

    unless current_user.valid_password?(two_factor_authentication_params[:current_password])
      @error_message = t(".invalid_password")
      render :show, status: :unprocessable_content
      return
    end

    TwoFactorAuthentication.transaction do
      current_user.two_factor_recovery_codes.destroy_all
      @two_factor_authentication.destroy!
    end

    redirect_to two_factor_authentication_path, notice: t(".disabled"), status: :see_other
  end

  private

  def prepare_setup
    @setup_secret = session[:pending_two_factor_secret] ||= TwoFactorAuthentication.generate_secret
    @provisioning_uri = setup_authentication.provisioning_uri
    @qr_code_svg = RQRCode::QRCode.new(@provisioning_uri).as_svg(
      module_size: 4,
      standalone: true,
      use_path: true,
      viewbox: true
    )
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
