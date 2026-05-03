require "test_helper"

class TwoFactorRecoveryCodeGeneratorTest < ActiveSupport::TestCase
  test "generates ten unique formatted codes and stores only digests" do
    user = create(:user)

    raw_codes = TwoFactorRecoveryCodeGenerator.new.generate_for(user: user)

    assert_equal 10, raw_codes.size
    assert_equal raw_codes.size, raw_codes.uniq.size
    assert raw_codes.all? { |code| code.match?(/\A[a-z0-9]{5}-[a-z0-9]{5}\z/) }
    assert_equal 10, user.two_factor_recovery_codes.count
    raw_codes.each do |raw_code|
      refute_includes user.two_factor_recovery_codes.map(&:code_digest), raw_code
      assert user.two_factor_recovery_codes.any? { |recovery_code| recovery_code.matches_code?(raw_code) }
    end
  end

  test "replaces previous recovery codes" do
    user = create(:user)
    generator = TwoFactorRecoveryCodeGenerator.new
    generator.generate_for(user: user)
    old_ids = user.two_factor_recovery_codes.pluck(:id)

    generator.generate_for(user: user)

    assert_equal 10, user.two_factor_recovery_codes.count
    assert_empty old_ids & user.two_factor_recovery_codes.pluck(:id)
  end
end
