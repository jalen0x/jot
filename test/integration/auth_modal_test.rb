require "test_helper"

class AuthModalTest < ActionDispatch::IntegrationTest
  test "auth pages render inside the shared modal frame" do
    [ new_user_session_path, new_user_registration_path, new_user_password_path ].each do |path|
      get path, headers: { "Turbo-Frame" => "modal_content" }

      assert_response :success
      assert_select "turbo-frame#modal_content"
      assert_select "[data-controller='modal']"
      assert_select "form"
    end
  end

  test "unauthenticated auth pages do not render the global header" do
    get new_user_session_path

    assert_response :success
    assert_select "header", count: 0
    assert_select "h1", text: I18n.t("devise.sessions.new.sign_in")
  end

  test "auth pages use the Flowbite reference illustrations" do
    {
      new_user_session_path => "sign-in",
      new_user_registration_path => "sign-in",
      new_user_password_path => "girl-and-computer"
    }.each do |path, image_name|
      get path

      assert_response :success
      assert_select "img[src*='#{image_name}']"
      assert_select "img[src*='#{image_name}-dark']"
    end
  end

  test "password reset page uses the Flowbite reference illustration" do
    user = FactoryBot.create(:user)
    reset_token = user.send_reset_password_instructions

    get edit_user_password_path(reset_password_token: reset_token)

    assert_response :success
    assert_select "img[src*='girl-and-computer']"
    assert_select "img[src*='girl-and-computer-dark']"
  end
end
