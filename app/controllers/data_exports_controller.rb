class DataExportsController < ApplicationController
  before_action :authenticate_user!

  # POST /data_exports
  def create
    authorize :data_export
    csv = DataExport.new.transactions_csv(user: current_user)

    send_data csv,
      filename: "transactions-#{Time.zone.today.iso8601}.csv",
      type: "text/csv; charset=utf-8"
  end
end
