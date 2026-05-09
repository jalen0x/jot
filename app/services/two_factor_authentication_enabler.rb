class TwoFactorAuthenticationEnabler
  def enable(user:, otp_secret:)
    recovery_codes = nil

    TwoFactorAuthentication.transaction do
      user.create_two_factor_authentication!(otp_secret: otp_secret, enabled_at: Time.current)
      recovery_codes = TwoFactorRecoveryCodeGenerator.new.generate_for(user: user)
    end

    recovery_codes
  end
end
