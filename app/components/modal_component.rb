class ModalComponent < ViewComponent::Base
  renders_one :header
  renders_one :footer

  attr_reader :title, :size, :close_button, :body_class

  SIZES = {
    sm: "max-w-sm",
    md: "max-w-md",
    lg: "max-w-lg",
    xl: "max-w-xl",
    wide: "max-w-4xl"
  }.freeze

  def initialize(title: nil, size: :md, close_button: true, body_class: "px-6 py-4 text-body")
    @title = title
    @size = size
    @close_button = close_button
    @body_class = body_class
  end

  def size_class
    SIZES.fetch(size, SIZES[:md])
  end

  def close_button?
    close_button
  end
end
