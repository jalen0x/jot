class ApplicationLocksController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :require_application_unlock, only: [ :destroy, :unlock ]

  # GET /application_lock
  def show
    authorize :application_lock
    @application_lock = current_user.application_lock || current_user.build_application_lock
  end

  # POST /application_lock
  def create
    authorize :application_lock
    permitted = application_lock_params

    if current_user.application_lock.present?
      @application_lock = current_user.application_lock
      redirect_to application_lock_path, alert: "Application lock is already enabled."
    elsif !current_user.valid_password?(permitted[:current_password])
      @application_lock = current_user.build_application_lock
      render_show_error("Current password is incorrect.")
    elsif permitted[:pin_code] != permitted[:pin_code_confirmation]
      @application_lock = current_user.build_application_lock
      render_show_error("PIN code confirmation does not match.")
    elsif !valid_pin?(permitted[:pin_code])
      @application_lock = current_user.build_application_lock
      render_show_error("PIN code must be exactly six digits.")
    else
      current_user.create_application_lock!(pin_digest: ApplicationLock.digest(permitted[:pin_code]))
      mark_application_unlocked
      redirect_to application_lock_path, notice: "Application lock enabled."
    end
  end

  # DELETE /application_lock
  def destroy
    application_lock = current_user.application_lock
    authorize application_lock || :application_lock

    if application_lock.blank?
      redirect_to application_lock_path, alert: "Application lock is not enabled."
    elsif !current_user.valid_password?(current_password_param)
      @application_lock = application_lock
      @application_lock.errors.add(:base, "Current password is incorrect.")
      render :show, status: :unprocessable_content
    else
      application_lock.destroy!
      clear_application_unlock
      redirect_to application_lock_path, notice: "Application lock disabled."
    end
  end

  # POST /application_lock/lock
  def lock
    authorize :application_lock

    if current_user.application_lock.blank?
      redirect_to application_lock_path, alert: "Application lock is not enabled."
    else
      clear_application_unlock
      redirect_to unlock_application_lock_path, notice: "Application locked."
    end
  end

  # GET|POST /application_lock/unlock
  def unlock
    authorize :application_lock
    @application_lock = current_user.application_lock
    return render :unlock if request.get?

    if @application_lock.blank?
      redirect_to application_lock_path, alert: "Application lock is not enabled."
    elsif @application_lock.matches_pin?(unlock_params[:pin_code])
      mark_application_unlocked
      redirect_to dashboard_path, notice: "Application unlocked."
    else
      flash.now[:alert] = "PIN code is invalid."
      render :unlock, status: :unprocessable_content
    end
  end

  private

  def application_lock_params
    params.expect(application_lock: [ :current_password, :pin_code, :pin_code_confirmation ])
  end

  def unlock_params
    params.expect(application_lock: [ :pin_code ])
  end

  def current_password_param
    params.expect(application_lock: [ :current_password ])[:current_password]
  end

  def render_show_error(message)
    @application_lock.errors.add(:base, message)
    render :show, status: :unprocessable_content
  end

  def valid_pin?(pin)
    pin.to_s.match?(/\A\d{6}\z/)
  end
end
