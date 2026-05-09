class ApplicationLocksController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :require_application_unlock, only: :destroy

  # GET /application_lock
  def show
    authorize :application_lock
    @application_lock = current_user.application_lock_enabled? ? current_user.application_lock : current_user.build_application_lock
  end

  # POST /application_lock
  def create
    authorize :application_lock
    permitted = application_lock_params

    if current_user.application_lock_enabled?
      @application_lock = current_user.application_lock
      redirect_to application_lock_path, alert: t(".already_enabled")
    elsif !current_user.valid_password?(permitted[:current_password])
      @application_lock = current_user.build_application_lock
      render_show_error(t(".invalid_password"))
    elsif permitted[:pin_code] != permitted[:pin_code_confirmation]
      @application_lock = current_user.build_application_lock
      render_show_error(t(".pin_mismatch"))
    elsif !valid_pin?(permitted[:pin_code])
      @application_lock = current_user.build_application_lock
      render_show_error(t(".invalid_pin"))
    else
      current_user.create_application_lock!(pin: permitted[:pin_code])
      mark_application_unlocked
      redirect_to application_lock_path, notice: t(".enabled")
    end
  end

  # DELETE /application_lock
  def destroy
    application_lock = current_user.application_lock
    authorize application_lock || :application_lock

    if application_lock.blank?
      redirect_to application_lock_path, alert: t(".not_enabled"), status: :see_other
    elsif !current_user.valid_password?(current_password_param)
      @application_lock = application_lock
      @application_lock.errors.add(:base, t(".invalid_password"))
      render :show, status: :unprocessable_content
    else
      application_lock.destroy!
      clear_application_unlock
      redirect_to application_lock_path, notice: t(".disabled"), status: :see_other
    end
  end

  private

  def application_lock_params
    params.expect(application_lock: [ :current_password, :pin_code, :pin_code_confirmation ])
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
