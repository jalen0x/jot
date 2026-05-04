class ApiTokensController < ApplicationController
  before_action :authenticate_user!

  # GET /api_tokens
  def index
    authorize ApiToken
    @api_token = current_user.api_tokens.build
    load_api_tokens
  end

  # POST /api_tokens
  def create
    authorize ApiToken
    permitted = api_token_params

    unless current_user.valid_password?(permitted[:current_password])
      @api_token = current_user.api_tokens.build(name: permitted[:name])
      @api_token.errors.add(:base, "Current password is incorrect.")
      load_api_tokens
      render :index, status: :unprocessable_content
      return
    end

    result = ApiTokenIssuer.new.issue(user: current_user, attributes: permitted)

    if result.issued?
      @issued_token = result.raw_token
      @api_token = current_user.api_tokens.build
      load_api_tokens
      render :index, status: :created
    else
      @api_token = result.api_token
      load_api_tokens
      render :index, status: :unprocessable_content
    end
  end

  # DELETE /api_tokens/:id
  def destroy
    api_token = policy_scope(ApiToken).kept.find(params[:id])
    authorize api_token
    api_token.discard!

    redirect_to api_tokens_path, notice: "API token revoked.", status: :see_other
  end

  private

  def api_token_params
    params.expect(api_token: [ :name, :expires_in_days, :current_password ])
  end

  def load_api_tokens
    @api_tokens = policy_scope(ApiToken).active.order(last_used_at: :desc, created_at: :desc)
  end
end
