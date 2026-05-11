module FormField
  class InputComponent < ViewComponent::Base
    FIELD_METHODS = {
      password: :password_field,
      email: :email_field,
      number: :number_field,
      date: :date_field,
      datetime: :datetime_field,
      textarea: :text_area
    }.freeze

    DEFAULT_INPUT_CLASSES = "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body".freeze
    DEFAULT_LABEL_CLASSES = "block mb-2 text-sm font-medium text-heading".freeze
    FLOATING_INPUT_CLASSES = "block px-2.5 pb-2.5 pt-4 w-full text-sm text-heading bg-transparent rounded-base border border-default-medium appearance-none focus:outline-none focus:ring-0 focus:border-brand peer".freeze
    FLOATING_LABEL_CLASSES = "absolute text-sm text-body duration-300 transform -translate-y-4 scale-75 top-2 z-10 origin-[0] bg-neutral-primary-soft px-2 peer-focus:px-2 peer-focus:text-fg-brand peer-placeholder-shown:scale-100 peer-placeholder-shown:-translate-y-1/2 peer-placeholder-shown:top-1/2 peer-focus:top-2 peer-focus:scale-75 peer-focus:-translate-y-4 start-1".freeze

    attr_reader :form, :field, :label, :type, :variant, :placeholder, :options

    def initialize(form:, field:, label: nil, type: :text, variant: :default, placeholder: nil, **options)
      @form = form
      @field = field
      @label = label
      @type = type
      @variant = variant
      @placeholder = placeholder
      @options = options
    end

    def label_text
      label || field.to_s.humanize
    end

    def floating?
      variant == :floating
    end

    def field_method
      FIELD_METHODS.fetch(type, :text_field)
    end

    def input_classes
      floating? ? FLOATING_INPUT_CLASSES : DEFAULT_INPUT_CLASSES
    end

    def label_classes
      floating? ? FLOATING_LABEL_CLASSES : DEFAULT_LABEL_CLASSES
    end
  end
end
