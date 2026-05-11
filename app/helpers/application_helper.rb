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

  def app_shell_navigation_groups
    [
      {
        label: t("layouts.application.nav_groups.overview"),
        items: [
          { label: t("layouts.application.nav.dashboard"), path: dashboard_path, icon: :home, match: dashboard_path },
          { label: t("layouts.application.nav.reports"), path: reports_path, icon: :chart, match: reports_path }
        ]
      },
      {
        label: t("layouts.application.nav_groups.transaction_data"),
        items: [
          { label: t("layouts.application.nav.transactions"), path: transactions_path, icon: :list, match: transactions_path },
          { label: t("layouts.application.nav.insights"), path: insight_explorers_path, icon: :compass, match: insight_explorers_path },
          { label: t("layouts.application.nav.imports"), path: new_import_batch_path, icon: :upload, match: [ new_import_batch_path, import_batches_path ] },
          { label: t("layouts.application.nav.receipts"), path: new_receipt_recognition_path, icon: :receipt, match: [ new_receipt_recognition_path, receipt_recognitions_path ] }
        ]
      },
      {
        label: t("layouts.application.nav_groups.basis_data"),
        items: [
          { label: t("layouts.application.nav.accounts"), path: accounts_path, icon: :wallet, match: accounts_path },
          { label: t("layouts.application.nav.categories"), path: transaction_categories_path, icon: :grid, match: transaction_categories_path },
          { label: t("layouts.application.nav.tags"), path: transaction_tag_groups_path, icon: :tag, match: [ transaction_tag_groups_path, transaction_tags_path ] },
          { label: t("layouts.application.nav.templates"), path: transaction_templates_path, icon: :template, match: transaction_templates_path }
        ]
      },
      {
        label: t("layouts.application.nav_groups.miscellaneous"),
        items: [
          { label: t("layouts.application.nav.exchange_rates"), path: exchange_rate_catalog_path, icon: :swap, match: [ exchange_rate_catalog_path, user_custom_exchange_rates_path ] },
          { label: t("layouts.application.nav.data_management"), path: data_management_path, icon: :database, match: [ data_management_path, new_ledger_clearance_path ] }
        ]
      },
      {
        label: t("layouts.application.nav_groups.settings_security"),
        items: [
          { label: t("layouts.application.nav.profile"), path: user_profile_path, icon: :user, match: user_profile_path },
          { label: t("layouts.application.nav.preferences"), path: user_preference_path, icon: :settings, match: user_preference_path },
          { label: t("layouts.application.nav.api_tokens"), path: api_tokens_path, icon: :key, match: api_tokens_path },
          { label: t("layouts.application.nav.external_auth"), path: external_authentications_path, icon: :link, match: external_authentications_path },
          { label: t("layouts.application.nav.two_factor"), path: two_factor_authentication_path, icon: :shield, match: two_factor_authentication_path },
          { label: t("layouts.application.nav.app_lock"), path: application_lock_path, icon: :lock, match: application_lock_path }
        ]
      }
    ]
  end

  def app_shell_nav_item_classes(item)
    base = "group flex items-center gap-3 rounded-base px-3 py-2 text-sm font-medium transition"
    active = "bg-brand-softer text-fg-brand shadow-xs"
    inactive = "text-body hover:bg-neutral-tertiary-soft hover:text-heading"
    [ base, app_shell_active?(item) ? active : inactive ].join(" ")
  end

  def app_shell_icon(name, css_class: "h-5 w-5 shrink-0")
    paths = {
      home: "M3 10.5 12 3l9 7.5M5 9.5V20h5v-6h4v6h5V9.5",
      chart: "M4 19V5m0 14h16M8 16v-5m4 5V8m4 8v-9",
      list: "M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01",
      compass: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm3-12-2 5-5 2 2-5 5-2Z",
      upload: "M12 16V4m0 0 4 4m-4-4-4 4M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3",
      receipt: "M6 3h12v18l-3-2-3 2-3-2-3 2V3Zm3 5h6m-6 4h6m-6 4h4",
      wallet: "M4 7h16v12H4V7Zm0 0 3-4h10l3 4m12 6h4",
      grid: "M4 4h7v7H4V4Zm9 0h7v7h-7V4ZM4 13h7v7H4v-7Zm9 0h7v7h-7v-7Z",
      tag: "M4 4h7l9 9-7 7-9-9V4Zm4 4h.01",
      template: "M6 3h12v18H6V3Zm3 5h6M9 12h6m-6 4h4",
      swap: "M7 7h13m0 0-3-3m3 3-3 3M17 17H4m0 0 3-3m-3 3 3 3",
      database: "M12 5c4.4 0 8-1.3 8-3s-3.6-3-8-3-8 1.3-8 3 3.6 3 8 3Zm-8-3v6c0 1.7 3.6 3 8 3s8-1.3 8-3V2M4 8v6c0 1.7 3.6 3 8 3s8-1.3 8-3V8",
      user: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm7 9a7 7 0 0 0-14 0",
      settings: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Zm0-5v3m0 12v3M4.9 4.9l2.1 2.1m10 10 2.1 2.1M3 12h3m12 0h3M4.9 19.1 7 17m10-10 2.1-2.1",
      key: "M14 10a4 4 0 1 0-3.5 3.97L8 16.5V19H5.5L3 21.5M14 10h.01",
      link: "M10 13a5 5 0 0 0 7.07 0l2-2a5 5 0 0 0-7.07-7.07l-1.15 1.15M14 11a5 5 0 0 0-7.07 0l-2 2A5 5 0 0 0 12 20.07l1.15-1.15",
      shield: "M12 3 5 6v6c0 4.4 3 7.4 7 9 4-1.6 7-4.6 7-9V6l-7-3Z",
      lock: "M7 11V8a5 5 0 0 1 10 0v3M5 11h14v10H5V11Z"
    }
    tag.svg(class: css_class, aria: { hidden: true }, viewBox: "0 0 24 24", fill: "none") do
      tag.path(d: paths.fetch(name), stroke: "currentColor", "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2")
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

  def map_location_url(latitude, longitude)
    formatted_latitude = decimal_text(latitude)
    formatted_longitude = decimal_text(longitude)
    query = "mlat=#{formatted_latitude}&mlon=#{formatted_longitude}"

    "https://www.openstreetmap.org/?#{query}#map=16/#{formatted_latitude}/#{formatted_longitude}"
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

  def app_shell_active?(item)
    current_path = request.path
    Array(item[:match] || item[:path]).any? do |match|
      match = match.to_s.chomp("/")
      current_path == match || current_path.start_with?("#{match}/")
    end
  end

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
