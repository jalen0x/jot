require "test_helper"

class TwoFactorAuthenticationTest < ActionDispatch::IntegrationTest
  test "user without two factor authentication signs in with password" do
    user = FactoryBot.create(:user, password: "password123")

    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }

    assert_redirected_to root_path
  end

  test "user with two factor authentication is not signed in after password only" do
    user = create_two_factor_user

    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }

    assert_response :unprocessable_content
    main_markup = response.body.split("<main", 2).last
    assert_operator main_markup.index("girl-and-computer"), :<, main_markup.index("<h1")
    assert_select "h1", text: I18n.t("devise.sessions.two_factor.title")
    assert_select "form[action='#{user_session_path}']"
    assert_select "input#code-1[type='text'][maxlength='1']"
    assert_select "input#code-6[type='text'][maxlength='1']"
    assert_select ".second-factor-code-input", count: 0
    assert_nil session["warden.user.user.key"]
  end

  test "incorrect authenticator code does not sign in" do
    user = create_two_factor_user
    start_two_factor_challenge(user)

    post user_session_path, params: { second_factor_code: "000000" }

    assert_response :unprocessable_content
    assert_select "p", text: I18n.t("users.sessions.create.invalid_second_factor_code")
    assert_nil session["warden.user.user.key"]
  end

  test "authenticator app code signs in" do
    user = create_two_factor_user
    start_two_factor_challenge(user)

    post user_session_path, params: { second_factor_code: user.current_otp }

    assert_redirected_to root_path
  end

  test "backup code signs in once" do
    user = create_two_factor_user
    backup_code = user.generate_otp_backup_codes!.first
    user.save!

    start_two_factor_challenge(user)
    post user_session_path, params: { second_factor_code: backup_code }
    assert_redirected_to root_path

    delete destroy_user_session_path
    start_two_factor_challenge(user)
    post user_session_path, params: { second_factor_code: backup_code }

    assert_response :unprocessable_content
    assert_nil session["warden.user.user.key"]
  end

  test "password reset does not automatically sign in" do
    user = FactoryBot.create(:user, password: "password123")
    reset_token = user.send_reset_password_instructions

    put user_password_path, params: {
      user: {
        reset_password_token: reset_token,
        password: "new-password123",
        password_confirmation: "new-password123"
      }
    }

    assert_redirected_to new_user_session_path
    assert_nil session["warden.user.user.key"]
  end

  test "signed in user can enable two factor authentication" do
    user = FactoryBot.create(:user, password: "password123")
    sign_in_with_password(user)

    get edit_user_registration_path
    assert_response :success
    assert_select "h2", text: I18n.t("devise.registrations.edit.two_factor.title")

    get new_user_two_factor_path
    assert_response :success
    assert_select "h1", text: I18n.t("users.two_factor.new.title")

    code = ROTP::TOTP.new(session[:two_factor_setup_secret]).now
    post user_two_factor_path, params: { second_factor_code: code }

    assert_response :success
    assert_select "h1", text: I18n.t("users.two_factor.backup_codes.title")
    assert_predicate user.reload, :otp_required_for_login?
    assert_not_empty user.otp_backup_codes
  end

  test "signed in user can disable two factor authentication" do
    user = create_two_factor_user
    user.generate_otp_backup_codes!
    user.save!
    start_two_factor_challenge(user)
    post user_session_path, params: { second_factor_code: user.current_otp }
    assert_redirected_to root_path

    delete user_two_factor_path

    assert_redirected_to edit_user_registration_path
    user.reload
    refute user.otp_required_for_login?
    assert_nil user.otp_secret
    assert_empty user.otp_backup_codes
  end

  private

  def create_two_factor_user
    FactoryBot.create(:user, password: "password123").tap do |user|
      user.otp_secret = User.generate_otp_secret
      user.otp_required_for_login = true
      user.save!
    end
  end

  def start_two_factor_challenge(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    assert_response :unprocessable_content
  end

  def sign_in_with_password(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    assert_redirected_to root_path
  end
end
