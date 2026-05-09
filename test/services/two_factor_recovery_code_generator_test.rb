require "test_helper"

class TwoFactorRecoveryCodeGeneratorTest < ActiveSupport::TestCase
  setup { @user = FactoryBot.create(:user) }

  test "generates ten unique recovery codes for a user" do
    codes = TwoFactorRecoveryCodeGenerator.new.generate_for(user: @user)

    assert_equal TwoFactorRecoveryCodeGenerator::CODE_COUNT, codes.size
    assert_equal codes, codes.uniq
    assert_equal codes.size, @user.two_factor_recovery_codes.unused.count
  end

  test "raw codes match the xxxxx-xxxxx format" do
    codes = TwoFactorRecoveryCodeGenerator.new.generate_for(user: @user)

    assert(codes.all? { |code| code.match?(/\A[a-z0-9]{5}-[a-z0-9]{5}\z/) },
           "Expected all codes to match xxxxx-xxxxx, got #{codes.inspect}")
  end

  test "regenerating wipes the previous batch" do
    first = TwoFactorRecoveryCodeGenerator.new.generate_for(user: @user)
    second = TwoFactorRecoveryCodeGenerator.new.generate_for(user: @user)

    assert_equal 0, (first & second).size
    assert_equal TwoFactorRecoveryCodeGenerator::CODE_COUNT, @user.two_factor_recovery_codes.count
  end

  test "stored codes verify against their raw form" do
    codes = TwoFactorRecoveryCodeGenerator.new.generate_for(user: @user)
    raw = codes.first
    matching = @user.two_factor_recovery_codes.unused.find { |rc| rc.authenticate_code(raw) }

    refute_nil matching
  end
end
