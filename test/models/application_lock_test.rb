require "test_helper"

class ApplicationLockTest < ActiveSupport::TestCase
  test "stores only a digest and matches the correct pin" do
    application_lock = ApplicationLock.create!(user: create(:user), pin_digest: ApplicationLock.digest("123456"))

    refute_equal "123456", application_lock.pin_digest
    assert application_lock.matches_pin?("123456")
    refute application_lock.matches_pin?("000000")
  end

  test "normalizes pin whitespace before matching" do
    application_lock = ApplicationLock.create!(user: create(:user), pin_digest: ApplicationLock.digest(" 123456 "))

    assert application_lock.matches_pin?("123456")
  end

  test "allows only one application lock per user" do
    user = create(:user)
    ApplicationLock.create!(user: user, pin_digest: ApplicationLock.digest("123456"))
    duplicate = ApplicationLock.new(user: user, pin_digest: ApplicationLock.digest("654321"))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken", duplicate.errors.full_messages.to_sentence
  end
end
