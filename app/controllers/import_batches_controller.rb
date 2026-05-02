class ImportBatchesController < ApplicationController
  before_action :authenticate_user!

  # GET /import_batches/new
  def new
    @import_batch = current_user.import_batches.build
    authorize @import_batch
  end

  # POST /import_batches
  def create
    @import_batch = current_user.import_batches.build(import_batch_params)
    authorize @import_batch

    if @import_batch.save
      ImportBatchParserJob.perform_later(@import_batch.id)
      redirect_to import_batch_path(@import_batch), notice: "Import started."
    else
      render :new, status: :unprocessable_content
    end
  end

  # GET /import_batches/:id
  def show
    @import_batch = policy_scope(ImportBatch).find(params[:id])
    authorize @import_batch
  end

  private

  def import_batch_params
    params.expect(import_batch: [ :source_filename, :raw_csv ])
  end
end
