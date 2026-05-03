class Users::SessionsController < Devise::SessionsController
  # POST /users/sign_in
  def create
    self.resource = warden.authenticate!(auth_options.merge(store: false))

    if resource.two_factor_enabled?
      session[:pending_two_factor_user_id] = resource.id
      redirect_to new_two_factor_challenge_path
    else
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource, force: true)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  end
end
