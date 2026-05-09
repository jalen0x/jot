require "test_helper"

class ApplicationLockTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user)
    @lock = @user.create_application_lock!(pin: "123456")
  end

  test "pin= hashes and persists only the digest" do
    assert @lock.pin_digest.present?
    refute_equal "123456", @lock.pin_digest
  end

  test "authenticate_pin accepts the original pin" do
    assert @lock.authenticate_pin("123456")
  end

  test "authenticate_pin tolerates surrounding whitespace" do
    assert @lock.authenticate_pin("  123456  ")
  end

  test "authenticate_pin rejects a wrong pin" do
    refute @lock.authenticate_pin("000000")
  end

  test "authenticate_pin returns false when digest is blank" do
    refute ApplicationLock.new.authenticate_pin("123456")
  end

  test "is invalid when PIN is not exactly six digits" do
    [ "abcdef", "12345", "1234567" ].each do |bad|
      lock = ApplicationLock.new(user: FactoryBot.create(:user), pin: bad, pin_confirmation: bad)
      refute lock.valid?, "Expected #{bad.inspect} to be rejected"
      assert_includes lock.errors[:pin], "is invalid"
    end
  end

  test "is invalid when PIN confirmation does not match" do
    lock = ApplicationLock.new(user: FactoryBot.create(:user), pin: "123456", pin_confirmation: "654321")
    refute lock.valid?
    assert_not_empty lock.errors[:pin_confirmation]
  end

  test "PIN normalisation applies to both pin and pin_confirmation before comparison" do
    lock = ApplicationLock.new(user: FactoryBot.create(:user), pin: "  123456  ", pin_confirmation: "123456")
    assert lock.valid?, lock.errors.full_messages.inspect
  end

  test "user_id is unique per user" do
    other = FactoryBot.create(:user)
    other.create_application_lock!(pin: "111111")

    duplicate = ApplicationLock.new(user: @user, pin: "999999")
    refute duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end
end
