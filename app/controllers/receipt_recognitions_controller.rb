class ReceiptRecognitionsController < ApplicationController
  before_action :authenticate_user!

  # GET /receipt_recognitions/new
  def new
    @receipt_recognition = current_user.receipt_recognitions.build
    authorize @receipt_recognition
  end

  # POST /receipt_recognitions
  def create
    @receipt_recognition = current_user.receipt_recognitions.build(status: :pending)
    @receipt_recognition.image.attach(receipt_recognition_params[:image])
    authorize @receipt_recognition

    if @receipt_recognition.save
      ReceiptRecognitionJob.perform_later(@receipt_recognition.id)
      redirect_to receipt_recognition_path(@receipt_recognition), notice: "Receipt recognition started."
    else
      render :new, status: :unprocessable_content
    end
  end

  # GET /receipt_recognitions/:id
  def show
    @receipt_recognition = policy_scope(ReceiptRecognition).find(params[:id])
    authorize @receipt_recognition
  end

  private

  def receipt_recognition_params
    params.expect(receipt_recognition: [ :image ])
  end
end
