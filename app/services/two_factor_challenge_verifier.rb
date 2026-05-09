class TwoFactorChallengeVerifier
  def verify(user:, code:)
    return Result.new(verified: false) if code.blank?

    if user.two_factor_authentication&.verify_otp(code)
      return Result.new(verified: true, used_recovery_code: false)
    end

    if user.two_factor_recovery_codes.unused.find { |candidate| candidate.consume!(code) }
      Result.new(verified: true, used_recovery_code: true)
    else
      Result.new(verified: false)
    end
  end

  class Result
    def initialize(verified:, used_recovery_code: false)
      @verified = verified
      @used_recovery_code = used_recovery_code
    end

    def verified? = @verified
    def used_recovery_code? = @used_recovery_code
  end
end
