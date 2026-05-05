class TransactionPicture
  def self.wrap(attachments)
    attachments.map { |attachment| new(attachment:) }
  end

  def initialize(attachment:)
    @attachment = attachment
  end

  def as_json(_options = {})
    {
      id: attachment.id,
      filename: attachment.filename.to_s,
      content_type: attachment.content_type,
      byte_size: attachment.byte_size,
      url: Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
    }
  end

  private

  attr_reader :attachment
end
