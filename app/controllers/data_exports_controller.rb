class DataExportsController < ApplicationController
  before_action :authenticate_user!

  # POST /data_exports
  def create
    authorize :data_export
    export = DataExport.new
    tsv = params[:file_format] == "tsv"

    send_data tsv ? export.transactions_tsv(user: current_user) : export.transactions_csv(user: current_user),
      filename: "transactions-#{Time.zone.today.iso8601}.#{tsv ? "tsv" : "csv"}",
      type: tsv ? "text/tab-separated-values; charset=utf-8" : "text/csv; charset=utf-8"
  end
end
