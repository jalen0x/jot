class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :redirect_locked_profile
  helper_method :profile_locked?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def profile_locked?
    user_signed_in? && session[:profile_locked].present?
  end

  def redirect_locked_profile
    return unless profile_locked?
    return if controller_path == "users/profile_locks"
    return if devise_controller? && controller_name == "sessions" && action_name == "destroy"

    redirect_to user_profile_lock_path
  end
end
