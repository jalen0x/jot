class Users::ProfileLocksController < ApplicationController
  before_action :authenticate_user!

  def show
  end

  def create
    session[:profile_locked] = true
    redirect_to user_profile_lock_path, status: :see_other
  end

  def destroy
    if current_user.valid_password?(params[:password])
      session.delete(:profile_locked)
      redirect_to root_path, status: :see_other
    else
      flash.now[:alert] = t(".invalid_password")
      render :show, status: :unprocessable_content
    end
  end
end
