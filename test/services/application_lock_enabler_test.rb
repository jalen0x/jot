require "test_helper"

class ApplicationLockEnablerTest < ActiveSupport::TestCase
  setup { @user = FactoryBot.create(:user, password: "password123") }

  test "enables the lock and persists a digest" do
    result = ApplicationLockEnabler.new.enable(
      user: @user,
      current_password: "password123",
      pin: "123456",
      pin_confirmation: "123456"
    )

    assert_predicate result, :enabled?
    assert @user.reload.application_lock_enabled?
    assert_predicate result.application_lock, :persisted?
    assert result.application_lock.pin_digest.present?
  end

  test "returns the unsaved lock with errors when current password is wrong" do
    result = ApplicationLockEnabler.new.enable(
      user: @user,
      current_password: "wrong",
      pin: "123456",
      pin_confirmation: "123456"
    )

    refute_predicate result, :enabled?
    refute_predicate result.application_lock, :persisted?
    assert_not_empty result.application_lock.errors[:base]
  end

  test "returns the unsaved lock with errors when PIN format is wrong" do
    result = ApplicationLockEnabler.new.enable(
      user: @user,
      current_password: "password123",
      pin: "abcdef",
      pin_confirmation: "abcdef"
    )

    refute_predicate result, :enabled?
    refute_predicate result.application_lock, :persisted?
    assert_includes result.application_lock.errors[:pin], "is invalid"
  end

  test "returns the unsaved lock with errors when confirmation does not match" do
    result = ApplicationLockEnabler.new.enable(
      user: @user,
      current_password: "password123",
      pin: "123456",
      pin_confirmation: "654321"
    )

    refute_predicate result, :enabled?
    assert_not_empty result.application_lock.errors[:pin_confirmation]
  end
end
