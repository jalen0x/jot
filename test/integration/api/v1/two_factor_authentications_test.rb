require "test_helper"
require "rotp"

class ApiV1TwoFactorAuthenticationsTest < ActionDispatch::IntegrationTest
  SECRET = "JBSWY3DPEHPK3PXP"

  test "shows disabled status for the token owner" do
    user = create(:user)
    create_two_factor_user
    raw_token = issue_token(user)

    get api_v1_two_factor_authentication_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "two_factor_authentication" ], body.keys
    assert_equal({ "enabled" => false }, body.fetch("two_factor_authentication"))
  end

  test "shows enabled status without internal secret fields" do
    user = create_two_factor_user
    raw_token = issue_token(user)

    get api_v1_two_factor_authentication_path, headers: json_headers(raw_token)

    assert_response :success
    two_factor_json = JSON.parse(response.body).fetch("two_factor_authentication")
    assert_equal true, two_factor_json.fetch("enabled")
    assert two_factor_json.fetch("enabled_at").present?
    refute_includes two_factor_json.keys, "otp_secret"
    refute_includes two_factor_json.keys, "user_id"
  end

  test "creates a setup secret after current password verification" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user)

    with_stubbed_secret(SECRET) do
      post api_v1_two_factor_setup_path,
        params: { two_factor_setup: { current_password: "password123" } },
        headers: json_headers(raw_token),
        as: :json
    end

    assert_response :created
    setup_json = JSON.parse(response.body).fetch("two_factor_setup")
    assert_equal SECRET, setup_json.fetch("otp_secret")
    assert_match %r{\Aotpauth://totp/}, setup_json.fetch("provisioning_uri")
    assert_match SECRET, setup_json.fetch("provisioning_uri")
    refute_predicate user.reload, :two_factor_enabled?
  end

  test "enables two-factor authentication with current password and valid code" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user)

    post api_v1_two_factor_authentication_path,
      params: {
        two_factor_authentication: {
          current_password: "password123",
          otp_secret: SECRET,
          otp_code: current_code
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    assert_predicate user.reload, :two_factor_enabled?
    two_factor_json = JSON.parse(response.body).fetch("two_factor_authentication")
    assert_equal true, two_factor_json.fetch("enabled")
    refute_includes two_factor_json.keys, "otp_secret"

    raw_codes = JSON.parse(response.body).fetch("two_factor_recovery_codes")
    assert_equal 10, raw_codes.uniq.size
    raw_codes.each do |raw_code|
      assert_match(/\A[a-z0-9]{5}-[a-z0-9]{5}\z/, raw_code)
      assert user.two_factor_recovery_codes.any? { |recovery_code| recovery_code.authenticate_code(raw_code) }
    end
  end

  test "rejects invalid code when enabling" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user)

    post api_v1_two_factor_authentication_path,
      params: {
        two_factor_authentication: {
          current_password: "password123",
          otp_secret: SECRET,
          otp_code: "000000"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    refute_predicate user.reload, :two_factor_enabled?
    assert_empty user.two_factor_recovery_codes
    assert_match(/Verification code is invalid/i, response.body)
  end

  test "rejects malformed setup secret when enabling" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user)

    post api_v1_two_factor_authentication_path,
      params: {
        two_factor_authentication: {
          current_password: "password123",
          otp_secret: "not-base32",
          otp_code: "000000"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    refute_predicate user.reload, :two_factor_enabled?
    assert_empty user.two_factor_recovery_codes
    assert_match(/Verification code is invalid/i, response.body)
  end

  test "disables two-factor authentication with current password" do
    user = create_two_factor_user
    raw_token = issue_token(user)

    delete api_v1_two_factor_authentication_path,
      params: { two_factor_authentication: { current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    refute_predicate user.reload, :two_factor_enabled?
    assert_empty user.two_factor_recovery_codes
  end

  test "regenerates recovery codes after current password verification" do
    user = create_two_factor_user
    old_ids = user.two_factor_recovery_codes.pluck(:id)
    raw_token = issue_token(user)

    post api_v1_two_factor_recovery_codes_path,
      params: { two_factor_recovery_codes: { current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    raw_codes = JSON.parse(response.body).fetch("two_factor_recovery_codes")
    assert_equal 10, raw_codes.uniq.size
    assert_empty old_ids & user.two_factor_recovery_codes.reload.pluck(:id)
    raw_codes.each do |raw_code|
      assert user.two_factor_recovery_codes.any? { |recovery_code| recovery_code.authenticate_code(raw_code) }
    end
    refute_match(/code_digest/, response.body)
  end

  private

  def create_two_factor_user
    user = create(:user, password: "password123")
    user.create_two_factor_authentication!(otp_secret: SECRET, enabled_at: Time.current)
    TwoFactorRecoveryCodeGenerator.new.generate_for(user: user)
    user
  end

  def current_code
    ROTP::TOTP.new(SECRET).now
  end

  def with_stubbed_secret(secret)
    original = TwoFactorAuthentication.method(:generate_secret)
    TwoFactorAuthentication.define_singleton_method(:generate_secret) { secret }
    yield
  ensure
    TwoFactorAuthentication.define_singleton_method(:generate_secret, original)
  end

  def issue_token(user)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: "API", expires_in_days: "" }).raw_token
  end

  def json_headers(raw_token)
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{raw_token}"
    }
  end
end
