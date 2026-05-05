class Api::V1::TransactionPicturesController < ApiController
  before_action :set_transaction

  # GET /api/v1/transactions/:transaction_id/pictures
  def index
    authorize @transaction, :show?

    render json: { pictures: TransactionPicture.wrap(@transaction.pictures.attachments) }
  end

  # POST /api/v1/transactions/:transaction_id/pictures
  def create
    authorize @transaction, :update?
    @transaction.pictures.attach(picture_attachable)

    render json: { picture: TransactionPicture.new(attachment: @transaction.pictures.attachments.last) }, status: :created
  end

  # DELETE /api/v1/transactions/:transaction_id/pictures/:id
  def destroy
    authorize @transaction, :update?
    attachment = @transaction.pictures.attachments.find(params[:id])
    attachment.purge

    head :no_content
  end

  private

  def set_transaction
    @transaction = policy_scope(Transaction).kept.find(params[:transaction_id])
  end

  def picture_attachable
    file = params.expect(:picture)
    return file unless file.respond_to?(:tempfile)

    {
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type,
      identify: false
    }
  end
end
