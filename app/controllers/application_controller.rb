class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Legacy session-flag profile lock — removed in a follow-up commit.
  before_action :redirect_locked_profile
  helper_method :profile_locked?

  # New PIN-based application lock.
  before_action :require_application_unlock
  helper_method :application_lock_unlocked?

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

  def require_application_unlock
    user = warden.user(:user)
    return if user.blank?
    return unless user.application_lock_enabled?
    return if application_lock_unlocked?

    redirect_to new_application_lock_session_path, alert: t("application_locks.locked_alert")
  end

  def application_lock_unlocked?
    session[:application_lock_unlocked_user_id] == warden.user(:user)&.id
  end

  def mark_application_unlocked
    session[:application_lock_unlocked_user_id] = current_user.id
  end

  def clear_application_unlock
    session.delete(:application_lock_unlocked_user_id)
  end
end
