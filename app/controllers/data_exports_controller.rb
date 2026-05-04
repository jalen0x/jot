class DataExportsController < ApplicationController
  before_action :authenticate_user!

  # POST /data_exports
  def create
    authorize :data_export
    file_format = params[:file_format].presence || "csv"

    unless %w[csv tsv].include?(file_format)
      render plain: "File format must be csv or tsv", status: :unprocessable_content
      return
    end

    export = DataExport.new
    tsv = file_format == "tsv"

    send_data tsv ? export.transactions_tsv(user: current_user) : export.transactions_csv(user: current_user),
      filename: "transactions-#{Time.zone.today.iso8601}.#{tsv ? "tsv" : "csv"}",
      type: tsv ? "text/tab-separated-values; charset=utf-8" : "text/csv; charset=utf-8"
  end
end
