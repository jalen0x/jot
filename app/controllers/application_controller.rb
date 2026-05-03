class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_application_unlock

  private

  def require_application_unlock
    return unless user_signed_in?
    return unless current_user.application_lock_enabled?
    return if application_lock_unlocked?
    return if application_lock_unlock_request?

    redirect_to unlock_application_lock_path, alert: "Unlock your application to continue."
  end

  def application_lock_unlocked?
    session[:application_lock_unlocked_user_id] == current_user.id
  end

  def mark_application_unlocked
    session[:application_lock_unlocked_user_id] = current_user.id
  end

  def clear_application_unlock
    session.delete(:application_lock_unlocked_user_id)
  end

  def application_lock_unlock_request?
    controller_path == "application_locks" && action_name == "unlock"
  end
end
