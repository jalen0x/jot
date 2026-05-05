module ApplicationHelper
  AMOUNT_COLOR_CLASSES = {
    "success" => "text-fg-success",
    "danger" => "text-fg-danger",
    "warning" => "text-fg-warning",
    "neutral" => "text-heading"
  }.freeze

  def amount_color_class(transaction_kind)
    case transaction_kind.to_s
    when "expense"
      AMOUNT_COLOR_CLASSES.fetch(preferred_expense_amount_color)
    when "income"
      AMOUNT_COLOR_CLASSES.fetch(preferred_income_amount_color)
    else
      AMOUNT_COLOR_CLASSES.fetch("neutral")
    end
  end

  def format_coordinates(latitude, longitude)
    coordinates = formatted_coordinates(latitude, longitude)

    case preferred_coordinate_display_format
    when /\Alongitude_latitude/
      "#{coordinates.fetch(:longitude)}, #{coordinates.fetch(:latitude)}"
    else
      "#{coordinates.fetch(:latitude)}, #{coordinates.fetch(:longitude)}"
    end
  end

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

  def preferred_coordinate_display_format
    current_user&.user_preference&.coordinate_display_format || UserPreference::DEFAULT_COORDINATE_DISPLAY_FORMAT
  end

  def preferred_expense_amount_color
    current_user&.user_preference&.expense_amount_color || UserPreference::DEFAULT_EXPENSE_AMOUNT_COLOR
  end

  def preferred_income_amount_color
    current_user&.user_preference&.income_amount_color || UserPreference::DEFAULT_INCOME_AMOUNT_COLOR
  end

  def formatted_coordinates(latitude, longitude)
    case preferred_coordinate_display_format
    when /\A.+_decimal_minutes/
      {
        latitude: coordinate_decimal_minutes(latitude, :latitude),
        longitude: coordinate_decimal_minutes(longitude, :longitude)
      }
    when /\A.+_degrees_minutes_seconds/
      {
        latitude: coordinate_degrees_minutes_seconds(latitude, :latitude),
        longitude: coordinate_degrees_minutes_seconds(longitude, :longitude)
      }
    else
      {
        latitude: decimal_text(latitude),
        longitude: decimal_text(longitude)
      }
    end
  end

  def coordinate_decimal_minutes(value, axis)
    absolute_value = BigDecimal(value.to_s).abs
    degrees = absolute_value.floor
    minutes = ((absolute_value - degrees) * 60).round(3)

    "#{degrees} deg #{decimal_text(minutes)} min #{coordinate_direction(value, axis)}"
  end

  def coordinate_degrees_minutes_seconds(value, axis)
    absolute_value = BigDecimal(value.to_s).abs
    degrees = absolute_value.floor
    decimal_minutes = (absolute_value - degrees) * 60
    minutes = decimal_minutes.floor
    seconds = ((decimal_minutes - minutes) * 60).round(2)

    "#{degrees} deg #{minutes} min #{decimal_text(seconds)} sec #{coordinate_direction(value, axis)}"
  end

  def coordinate_direction(value, axis)
    if axis == :latitude
      BigDecimal(value.to_s).negative? ? "S" : "N"
    else
      BigDecimal(value.to_s).negative? ? "W" : "E"
    end
  end

  def decimal_text(value)
    text = value.to_d.to_s("F")
    return text unless text.include?(".")

    text.sub(/0+\z/, "").sub(/\.\z/, "")
  end
end
