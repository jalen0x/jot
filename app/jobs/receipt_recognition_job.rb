class ReceiptRecognitionJob < ApplicationJob
  discard_on ActiveJob::DeserializationError
  discard_on ActiveRecord::RecordNotFound

  # Receipts can fail for configuration or provider reasons; leave failures visible in Solid Queue.
  # POST /receipt_recognitions enqueues this job after persisting the image.
  def perform(receipt_recognition_id)
    receipt_recognition = ReceiptRecognition.find(receipt_recognition_id)
    ReceiptRecognitionProcessor.new.process(receipt_recognition: receipt_recognition)
  end
end
