class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :switch_locale
  before_action :require_application_unlock

  private

  def switch_locale(&action)
    I18n.with_locale(preferred_locale, &action)
  end

  def preferred_locale
    warden.user(:user)&.user_preference&.locale.presence || I18n.default_locale
  end

  def require_application_unlock
    user = warden.user(:user)
    return if user.blank?
    return unless user.application_lock_enabled?
    return if application_lock_unlocked?
    return if application_lock_unlock_request?

    redirect_to unlock_application_lock_path, alert: "Unlock your application to continue."
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

  def application_lock_unlock_request?
    controller_path == "application_locks" && action_name == "unlock"
  end
end
