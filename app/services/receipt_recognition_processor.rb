class ReceiptRecognitionProcessor
  def initialize(client: ReceiptRecognitionClient.new)
    @client = client
  end

  def process(receipt_recognition:)
    update_and_broadcast(receipt_recognition, status: :processing, error_message: nil)
    result = recognize(receipt_recognition)
    update_and_broadcast(receipt_recognition, status: :succeeded, result_json: result, error_message: nil)
  rescue ReceiptRecognitionClient::Error => error
    update_and_broadcast(receipt_recognition, status: :failed, error_message: error.message)
    raise
  end

  private

  def update_and_broadcast(receipt_recognition, attributes)
    receipt_recognition.update!(attributes)
    receipt_recognition.broadcast_replace
  end

  def recognize(receipt_recognition)
    receipt_recognition.image.open do |file|
      @client.recognize(
        image_bytes: file.read,
        content_type: receipt_recognition.image.blob.content_type
      )
    end
  end
end
