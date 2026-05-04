class Api::V1::ApiTokensController < ApiController
  # GET /api/v1/api_tokens
  def index
    authorize ApiToken
    api_tokens = policy_scope(ApiToken).active.order(last_used_at: :desc, created_at: :desc)

    render json: { api_tokens: api_tokens }
  end

  # POST /api/v1/api_tokens
  def create
    authorize ApiToken
    permitted = api_token_params

    unless current_user.valid_password?(permitted[:current_password])
      render json: { errors: [ "Current password is incorrect." ] }, status: :unprocessable_content
      return
    end

    result = ApiTokenIssuer.new.issue(user: current_user, attributes: permitted)

    if result.issued?
      render json: { api_token: result.api_token, raw_token: result.raw_token }, status: :created
    else
      render json: { errors: result.api_token.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/api_tokens/:id
  def destroy
    api_token = policy_scope(ApiToken).kept.find(params[:id])
    authorize api_token
    api_token.discard!

    head :no_content
  end

  private

  def api_token_params
    params.expect(api_token: [ :name, :expires_in_days, :current_password ])
  end
end
