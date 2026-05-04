class Api::V1::ApplicationLocksController < ApiController
  # GET /api/v1/application_lock
  def show
    authorize :application_lock

    render json: { application_lock: current_user.application_lock || { enabled: false } }
  end

  # POST /api/v1/application_lock
  def create
    authorize :application_lock
    permitted = application_lock_params

    if current_user.application_lock_enabled?
      render_unprocessable("Application lock is already enabled.")
    elsif !current_user.valid_password?(permitted[:current_password])
      render_unprocessable("Current password is incorrect.")
    elsif permitted[:pin_code] != permitted[:pin_code_confirmation]
      render_unprocessable("PIN code confirmation does not match.")
    elsif !valid_pin?(permitted[:pin_code])
      render_unprocessable("PIN code must be exactly six digits.")
    else
      application_lock = current_user.create_application_lock!(pin_digest: ApplicationLock.digest(permitted[:pin_code]))
      render json: { application_lock: application_lock }, status: :created
    end
  end

  # DELETE /api/v1/application_lock
  def destroy
    authorize :application_lock
    application_lock = current_user.application_lock

    if application_lock.blank?
      render_unprocessable("Application lock is not enabled.")
    elsif !current_user.valid_password?(application_lock_params[:current_password])
      render_unprocessable("Current password is incorrect.")
    else
      application_lock.destroy!
      head :no_content
    end
  end

  private

  def application_lock_params
    params.expect(application_lock: [ :current_password, :pin_code, :pin_code_confirmation ])
  end

  def render_unprocessable(message)
    render json: { errors: [ message ] }, status: :unprocessable_content
  end

  def valid_pin?(pin)
    pin.to_s.match?(/\A\d{6}\z/)
  end
end
