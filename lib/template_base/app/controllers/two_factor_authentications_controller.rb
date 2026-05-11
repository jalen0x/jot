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

    if current_user.two_factor_enabled?
      redirect_to two_factor_authentication_path, notice: t(".already_enabled")
      return
    end

    permitted = two_factor_authentication_params
    result = TwoFactorAuthenticationEnabler.new.enable(
      user: current_user,
      current_password: permitted[:current_password],
      otp_code: permitted[:otp_code],
      otp_secret: session[:pending_two_factor_secret]
    )

    if result.enabled?
      session.delete(:pending_two_factor_secret)
      @two_factor_authentication = result.two_factor_authentication
      @recovery_codes = result.recovery_codes
      flash.now[:notice] = t(".enabled")
      render :show, status: :created
    elsif result.error == :invalid_setup
      session.delete(:pending_two_factor_secret)
      redirect_to two_factor_authentication_path, alert: t(".session_expired")
    else
      @error_message = t(".#{result.error}")
      prepare_setup
      render :show, status: :unprocessable_content
    end
  end

  # DELETE /two_factor_authentication
  def destroy
    @two_factor_authentication = current_user.two_factor_authentication

    unless @two_factor_authentication
      redirect_to two_factor_authentication_path, notice: t(".not_enabled"), status: :see_other
      return
    end

    authorize @two_factor_authentication

    result = TwoFactorAuthenticationDisabler.new.disable(
      user: current_user,
      current_password: two_factor_authentication_params[:current_password]
    )

    if result.disabled?
      redirect_to two_factor_authentication_path, notice: t(".disabled"), status: :see_other
    else
      @error_message = t(".#{result.error}")
      render :show, status: :unprocessable_content
    end
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

  def two_factor_authentication_params
    params.expect(two_factor_authentication: [ :current_password, :otp_code ])
  end
end
