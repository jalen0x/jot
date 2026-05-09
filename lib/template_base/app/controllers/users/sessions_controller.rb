class Users::SessionsController < Devise::SessionsController
  before_action :enforce_login_rate_limit, only: :create
  skip_before_action :require_application_unlock, only: :destroy

  # POST /users/sign_in
  def create
    self.resource = warden.authenticate(auth_options.merge(store: false))

    unless resource
      login_attempt_limiter.record_failure(email: login_email, ip: request.remote_ip)
      self.resource = resource_class.new(email: login_email)
      flash.now[:alert] = t(".invalid_credentials")
      render :new, status: :unprocessable_content
      return
    end

    login_attempt_limiter.reset(email: login_email, ip: request.remote_ip)

    if resource.two_factor_enabled?
      session[:pending_two_factor_user_id] = resource.id
      redirect_to new_two_factor_challenge_path
    else
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource, force: true)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  end

  private

  def enforce_login_rate_limit
    return unless login_attempt_limiter.blocked?(email: login_email, ip: request.remote_ip)

    self.resource = resource_class.new(email: login_email)
    flash.now[:alert] = t(".too_many_attempts")
    render :new, status: :too_many_requests
  end

  def login_attempt_limiter
    @login_attempt_limiter ||= LoginAttemptLimiter.new
  end

  def login_email
    params.dig(resource_name, :email)
  end
end
