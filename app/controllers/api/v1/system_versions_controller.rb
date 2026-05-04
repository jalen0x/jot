class Api::V1::SystemVersionsController < ApiController
  # GET /api/v1/system_version
  def show
    authorize :system_version

    render json: { system_version: SystemVersion.current }
  end
end
