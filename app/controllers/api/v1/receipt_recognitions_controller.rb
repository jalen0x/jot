class Api::V1::ReceiptRecognitionsController < ApiController
  # POST /api/v1/receipt_recognitions
  def create
    authorize ReceiptRecognition
    receipt_recognition = current_user.receipt_recognitions.build(status: :pending)
    image = receipt_recognition_params[:image]
    receipt_recognition.image.attach(image) if image.present?

    if receipt_recognition.save
      ReceiptRecognitionJob.perform_later(receipt_recognition.id)
      render json: { receipt_recognition: receipt_recognition }, status: :created
    else
      render json: { errors: receipt_recognition.errors.full_messages }, status: :unprocessable_content
    end
  end

  # GET /api/v1/receipt_recognitions/:id
  def show
    receipt_recognition = policy_scope(ReceiptRecognition).find(params[:id])
    authorize receipt_recognition

    render json: { receipt_recognition: receipt_recognition }
  end

  private

  def receipt_recognition_params
    params.expect(receipt_recognition: [ :image ])
  end
end
