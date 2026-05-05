class ApiController < ApplicationController
  rescue_from LedgerQuery::InvalidAmountFilter, LedgerQuery::InvalidDateFilter, with: :render_unprocessable_error

  before_action :require_json
  before_action :authenticate_api_token

  private

  attr_reader :current_api_token, :current_api_user

  def current_user
    current_api_user
  end

  def require_json
    return if request.format.json?

    head :not_acceptable
  end

  def authenticate_api_token
    authenticate_or_request_with_http_token do |token, _options|
      @current_api_token = ApiToken.authenticate(token)
      next false if current_api_token.blank?

      @current_api_user = current_api_token.user
      current_api_token.update!(last_used_at: Time.current)
      true
    end
  end

  def render_unprocessable_error(error)
    render json: { errors: [ error.message ] }, status: :unprocessable_content
  end
end
