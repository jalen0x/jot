class DataExportsController < ApplicationController
  before_action :authenticate_user!

  # POST /data_exports
  def create
    authorize :data_export
    file_format = params[:file_format].presence || "csv"

    unless %w[csv tsv json].include?(file_format)
      render plain: "File format must be csv, tsv, or json", status: :unprocessable_content
      return
    end

    export = DataExport.new

    send_data export_data(export, file_format),
      filename: "transactions-#{Time.zone.today.iso8601}.#{file_format}",
      type: export_type(file_format)
  end

  private

  def export_data(export, file_format)
    case file_format
    when "tsv"
      export.transactions_tsv(user: current_user)
    when "json"
      export.transactions_json(user: current_user)
    else
      export.transactions_csv(user: current_user)
    end
  end

  def export_type(file_format)
    case file_format
    when "tsv"
      "text/tab-separated-values; charset=utf-8"
    when "json"
      "application/json; charset=utf-8"
    else
      "text/csv; charset=utf-8"
    end
  end
end
