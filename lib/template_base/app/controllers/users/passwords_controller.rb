class Users::PasswordsController < Devise::PasswordsController
  protected

  def after_resetting_password_path_for(_resource)
    new_session_path(resource_name)
  end
end
