class Api::V1::DataExportsController < ApiController
  skip_before_action :require_json

  # POST /api/v1/data_exports
  def create
    authorize :data_export
    csv = DataExport.new.transactions_csv(user: current_user)

    send_data csv,
      filename: "transactions-#{Time.zone.today.iso8601}.csv",
      type: "text/csv; charset=utf-8"
  end
end
