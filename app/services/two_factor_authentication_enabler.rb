class TwoFactorAuthenticationEnabler
  def enable(user:, current_password:, otp_code:, otp_secret:)
    return Result.new(enabled: false, error: :invalid_password) unless user.valid_password?(current_password)

    record = user.build_two_factor_authentication(otp_secret: otp_secret, enabled_at: Time.current)
    return Result.new(enabled: false, error: :invalid_otp) unless record.verify_otp(otp_code)

    recovery_codes = nil
    TwoFactorAuthentication.transaction do
      record.save!
      recovery_codes = TwoFactorRecoveryCodeGenerator.new.generate_for(user: user)
    end

    Result.new(enabled: true, two_factor_authentication: record, recovery_codes: recovery_codes)
  end

  class Result
    attr_reader :two_factor_authentication, :recovery_codes, :error

    def initialize(enabled:, two_factor_authentication: nil, recovery_codes: nil, error: nil)
      @enabled = enabled
      @two_factor_authentication = two_factor_authentication
      @recovery_codes = recovery_codes
      @error = error
    end

    def enabled? = @enabled
  end
end
