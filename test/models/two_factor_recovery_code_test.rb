require "test_helper"

class TwoFactorRecoveryCodeTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user)
    @recovery_code = @user.two_factor_recovery_codes.create!(code: "abcde-fghij")
  end

  test "code= hashes and clears the raw value" do
    assert @recovery_code.code_digest.present?
    refute_equal "abcde-fghij", @recovery_code.code_digest
  end

  test "authenticate_code accepts the original code" do
    assert @recovery_code.authenticate_code("abcde-fghij")
  end

  test "authenticate_code is case-insensitive" do
    assert @recovery_code.authenticate_code("ABCDE-FGHIJ")
  end

  test "authenticate_code tolerates surrounding whitespace" do
    assert @recovery_code.authenticate_code("  abcde-fghij  ")
  end

  test "authenticate_code accepts the code without the formatting dash" do
    assert @recovery_code.authenticate_code("abcdefghij")
  end

  test "authenticate_code rejects a different code" do
    refute @recovery_code.authenticate_code("xxxxx-yyyyy")
  end

  test "consume! marks the code used and is single-use" do
    assert @recovery_code.consume!("abcde-fghij")
    assert @recovery_code.used?
    refute @recovery_code.consume!("abcde-fghij")
  end

  test "consume! returns false for a wrong code without marking it used" do
    refute @recovery_code.consume!("xxxxx-yyyyy")
    refute @recovery_code.reload.used?
  end

  test "unused scope excludes consumed codes" do
    other = @user.two_factor_recovery_codes.create!(code: "12345-67890")
    other.consume!("12345-67890")

    assert_includes @user.two_factor_recovery_codes.unused, @recovery_code
    refute_includes @user.two_factor_recovery_codes.unused, other
  end
end
