class ApplicationLockSessionsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :require_application_unlock

  # GET /application_lock_session/new
  def new
    authorize :application_lock_session
    @application_lock = current_user.application_lock
  end

  # POST /application_lock_session
  def create
    authorize :application_lock_session
    @application_lock = current_user.application_lock

    if @application_lock.blank?
      redirect_to application_lock_path, alert: "Application lock is not enabled."
    elsif @application_lock.matches_pin?(unlock_params[:pin_code])
      mark_application_unlocked
      redirect_to dashboard_path, notice: "Application unlocked."
    else
      flash.now[:alert] = "PIN code is invalid."
      render :new, status: :unprocessable_content
    end
  end

  # DELETE /application_lock_session
  def destroy
    authorize :application_lock_session

    if !current_user.application_lock_enabled?
      redirect_to application_lock_path, alert: "Application lock is not enabled.", status: :see_other
    else
      clear_application_unlock
      redirect_to new_application_lock_session_path, notice: "Application locked.", status: :see_other
    end
  end

  private

  def unlock_params
    params.expect(application_lock: [ :pin_code ])
  end
end
