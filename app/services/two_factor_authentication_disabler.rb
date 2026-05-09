class TwoFactorAuthenticationDisabler
  def disable(user:, current_password:)
    return Result.new(disabled: false, error: :invalid_password) unless user.valid_password?(current_password)

    TwoFactorAuthentication.transaction do
      user.two_factor_recovery_codes.destroy_all
      user.two_factor_authentication.destroy!
    end

    Result.new(disabled: true)
  end

  class Result
    attr_reader :error

    def initialize(disabled:, error: nil)
      @disabled = disabled
      @error = error
    end

    def disabled? = @disabled
  end
end
