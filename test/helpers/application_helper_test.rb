require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  def current_user = @current_user

  test "returns modal frame data inside a turbo frame request" do
    def turbo_frame_request? = true

    assert_equal({ turbo_frame: "modal_content" }, modal_turbo_frame_data)
  end

  test "returns empty hash on full page requests" do
    def turbo_frame_request? = false

    assert_equal({}, modal_turbo_frame_data)
  end

  test "formats money with preferred currency code position and number format" do
    @current_user = create(:user)
    UserPreference.create!(
      user: @current_user,
      default_currency_code: "USD",
      number_format: "decimal_comma",
      currency_display_format: "code_before_amount"
    )

    assert_equal "USD 12,34", format_money(1234, "USD")
  end

  test "formats money without a currency code when preferred" do
    @current_user = create(:user)
    UserPreference.create!(
      user: @current_user,
      default_currency_code: "USD",
      currency_display_format: "none"
    )

    assert_equal "12.34", format_money(1234, "USD")
  end

  test "formats coordinates in the default latitude longitude decimal degrees format" do
    assert_equal "37.7749, -122.4194", format_coordinates(BigDecimal("37.7749"), BigDecimal("-122.4194"))
  end

  test "formats coordinates with preferred order and units" do
    @current_user = create(:user)
    UserPreference.create!(
      user: @current_user,
      default_currency_code: "USD",
      coordinate_display_format: "longitude_latitude_degrees_minutes_seconds"
    )

    assert_equal "122 deg 25 min 9.84 sec W, 37 deg 46 min 29.64 sec N", format_coordinates(BigDecimal("37.7749"), BigDecimal("-122.4194"))
  end

  test "returns preferred semantic amount color classes" do
    @current_user = create(:user)
    UserPreference.create!(
      user: @current_user,
      default_currency_code: "USD",
      expense_amount_color: "warning",
      income_amount_color: "neutral"
    )

    assert_equal "text-fg-warning", amount_color_class(:expense)
    assert_equal "text-heading", amount_color_class(:income)
    assert_equal "text-heading", amount_color_class(:transfer)
  end
end
