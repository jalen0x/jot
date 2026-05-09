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

    if current_user.application_lock_enabled?
      redirect_to application_lock_path, alert: t(".already_enabled")
      return
    end

    permitted = application_lock_params
    result = ApplicationLockEnabler.new.enable(
      user: current_user,
      current_password: permitted[:current_password],
      pin: permitted[:pin],
      pin_confirmation: permitted[:pin_confirmation]
    )

    if result.enabled?
      mark_application_unlocked
      redirect_to application_lock_path, notice: t(".enabled")
    else
      @application_lock = result.application_lock
      render :show, status: :unprocessable_content
    end
  end

  # DELETE /application_lock
  def destroy
    application_lock = current_user.application_lock
    authorize application_lock || :application_lock

    if application_lock.blank?
      redirect_to application_lock_path, alert: t(".not_enabled"), status: :see_other
      return
    end

    result = ApplicationLockDisabler.new.disable(user: current_user, current_password: current_password_param)

    if result.disabled?
      clear_application_unlock
      redirect_to application_lock_path, notice: t(".disabled"), status: :see_other
    else
      @application_lock = result.application_lock
      render :show, status: :unprocessable_content
    end
  end

  private

  def application_lock_params
    params.expect(application_lock: [ :current_password, :pin, :pin_confirmation ])
  end

  def current_password_param
    params.expect(application_lock: [ :current_password ])[:current_password]
  end
end
