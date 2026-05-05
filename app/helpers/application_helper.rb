module ApplicationHelper
  def format_money(cents, currency_code, amount_options: {}, currency_class: nil)
    amount = number_to_currency(cents.to_f / 100, preferred_amount_format_options.merge(amount_options))
    code = currency_class.present? ? tag.span(currency_code, class: currency_class) : currency_code.to_s

    case preferred_currency_display_format
    when "code_before_amount"
      safe_join([ code, " ", amount ])
    when "none"
      amount
    else
      safe_join([ amount, " ", code ])
    end
  end

  # Returns data attributes for links/forms that should stay inside an open modal.
  def modal_turbo_frame_data
    turbo_frame_request? ? { turbo_frame: "modal_content" } : {}
  end

  def destructive_confirm_data(message, description: nil, accept: "Delete", reject: "Cancel", confirm_text: nil)
    data = {
      turbo_confirm: message,
      turbo_confirm_accept: accept,
      turbo_confirm_reject: reject
    }
    data[:turbo_confirm_description] = description if description.present?
    data[:turbo_confirm_text] = confirm_text if confirm_text.present?
    data
  end

  # Returns a smart back URL that prioritizes HTTP referer with same-origin
  # checks, falling back to the provided path when no valid referer exists.
  def smart_back_url(fallback_path = root_path)
    referer = request.referer
    valid_referer?(referer) ? referer : fallback_path
  end

  private

  def valid_referer?(referer)
    return false if referer.blank?
    return false if referer == request.url

    URI.parse(referer).host == request.host
  rescue URI::InvalidURIError
    false
  end

  def preferred_amount_format_options
    { unit: "" }.merge(current_user&.user_preference&.number_format_options || UserPreference.number_format_options_for(UserPreference::DEFAULT_NUMBER_FORMAT))
  end

  def preferred_currency_display_format
    current_user&.user_preference&.currency_display_format || UserPreference::DEFAULT_CURRENCY_DISPLAY_FORMAT
  end
end
