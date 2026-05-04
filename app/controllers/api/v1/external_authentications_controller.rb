class Api::V1::ExternalAuthenticationsController < ApiController
  # GET /api/v1/external_authentications
  def index
    authorize ExternalAuthentication

    render json: { external_authentications: ExternalAuthentication.for_user(current_user) }
  end

  # DELETE /api/v1/external_authentications/:id
  def destroy
    external_authentication = ExternalAuthentication.find_for_user!(current_user, params[:id])
    authorize external_authentication

    unless current_user.valid_password?(external_authentication_params[:current_password])
      render json: { errors: [ "Current password is incorrect." ] }, status: :unprocessable_content
      return
    end

    current_user.update!(provider: nil, uid: nil)

    head :no_content
  end

  private

  def external_authentication_params
    params.expect(external_authentication: [ :current_password ])
  end
end
