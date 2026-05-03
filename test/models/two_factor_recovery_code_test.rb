require "test_helper"

class TwoFactorRecoveryCodeTest < ActiveSupport::TestCase
  test "matches a raw recovery code against its digest" do
    recovery_code = build_recovery_code(raw_code: "abcde-fghij")

    assert recovery_code.matches_code?("abcde-fghij")
    refute recovery_code.matches_code?("wrong-code")
  end

  test "consume marks a matching unused recovery code as used" do
    recovery_code = build_recovery_code(raw_code: "abcde-fghij")

    assert recovery_code.consume!("abcde-fghij")
    assert_predicate recovery_code, :used?
    assert recovery_code.used_at.present?
  end

  test "consume rejects already used recovery codes" do
    recovery_code = build_recovery_code(raw_code: "abcde-fghij")
    recovery_code.consume!("abcde-fghij")

    refute recovery_code.consume!("abcde-fghij")
  end

  private

  def build_recovery_code(raw_code:)
    create(:user).two_factor_recovery_codes.create!(
      code_digest: TwoFactorRecoveryCode.digest(raw_code)
    )
  end
end
