require "test_helper"

class ApplicationLockDisablerTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user, password: "password123")
    @user.create_application_lock!(pin: "123456")
  end

  test "destroys the lock when current password matches" do
    result = ApplicationLockDisabler.new.disable(user: @user, current_password: "password123")

    assert_predicate result, :disabled?
    refute @user.reload.application_lock_enabled?
  end

  test "leaves the lock in place and reports errors when password is wrong" do
    result = ApplicationLockDisabler.new.disable(user: @user, current_password: "wrong")

    refute_predicate result, :disabled?
    assert_not_empty result.application_lock.errors[:base]
    assert @user.reload.application_lock_enabled?
  end
end
