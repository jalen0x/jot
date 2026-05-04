require "test_helper"

class UserProfilesTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get user_profile_path

    assert_redirected_to new_user_session_path
  end

  test "updates the signed-in user's display profile without changing email" do
    user = create(:user, email: "jalen@example.com", first_name: "Jalen", last_name: "X")
    sign_in user

    get user_profile_path

    assert_response :success
    assert_match(/jalen@example.com/i, response.body)

    patch user_profile_path, params: {
      user_profile: {
        first_name: "New",
        last_name: "Display",
        email: "changed@example.com"
      }
    }

    assert_redirected_to user_profile_path
    follow_redirect!
    assert_match(/Profile updated/i, response.body)
    assert_equal "New", user.reload.first_name
    assert_equal "Display", user.last_name
    assert_equal "jalen@example.com", user.email
  end

  test "uploads and removes the signed-in user's avatar" do
    user = create(:user)
    other_user = create(:user)
    other_user.avatar.attach(io: StringIO.new("other"), filename: "other.png", content_type: "image/png", identify: false)
    sign_in user

    post user_avatar_path, params: { avatar: fixture_file_upload("avatar.png", "image/png") }

    assert_redirected_to user_profile_path
    assert_predicate user.reload.avatar, :attached?
    assert_predicate other_user.reload.avatar, :attached?

    delete user_avatar_path

    assert_response :see_other
    assert_redirected_to user_profile_path
    refute_predicate user.reload.avatar, :attached?
    assert_predicate other_user.reload.avatar, :attached?
  end
end
