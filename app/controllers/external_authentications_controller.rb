class ExternalAuthenticationsController < ApplicationController
  before_action :authenticate_user!

  # GET /external_authentications
  def index
    authorize ExternalAuthentication
    load_external_authentications
  end

  # DELETE /external_authentications/:id
  def destroy
    external_authentication = ExternalAuthentication.find_for_user!(current_user, params[:id])
    authorize external_authentication

    unless current_user.valid_password?(external_authentication_params[:current_password])
      flash.now[:alert] = "Current password is incorrect."
      load_external_authentications
      render :index, status: :unprocessable_content
      return
    end

    current_user.update!(provider: nil, uid: nil)

    redirect_to external_authentications_path, notice: "External authentication disconnected.", status: :see_other
  end

  private

  def external_authentication_params
    params.expect(external_authentication: [ :current_password ])
  end

  def load_external_authentications
    @external_authentications = ExternalAuthentication.for_user(current_user)
  end
end
