class Api::V1::ApiTokenClearancesController < ApiController
  # POST /api/v1/api_token_clearance
  def create
    authorize :api_token_clearance
    revoked_count = policy_scope(ApiToken).kept.where.not(id: current_api_token.id).update_all(
      discarded_at: Time.current,
      updated_at: Time.current
    )

    render json: { api_token_clearance: { revoked_count: revoked_count } }, status: :created
  end
end
