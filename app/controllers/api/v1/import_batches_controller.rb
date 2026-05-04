class Api::V1::ImportBatchesController < ApiController
  # GET /api/v1/import_batches/:id
  def show
    import_batch = scoped_import_batch
    authorize import_batch

    render json: { import_batch: import_batch.as_json }
  end

  # POST /api/v1/import_batches
  def create
    import_batch = current_user.import_batches.build(import_batch_params)
    authorize import_batch

    if import_batch.save
      ImportBatchParserJob.perform_later(import_batch.id)
      render json: { import_batch: import_batch.as_json }, status: :created
    else
      render json: { errors: import_batch.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def import_batch_params
    params.expect(import_batch: [ :source_filename, :raw_csv ])
  end

  def scoped_import_batch
    policy_scope(ImportBatch).find(params[:id])
  end
end
