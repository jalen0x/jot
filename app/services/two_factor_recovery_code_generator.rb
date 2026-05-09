class TwoFactorRecoveryCodeGenerator
  CODE_COUNT = 10

  def generate_for(user:)
    raw_codes = generate_raw_codes

    TwoFactorRecoveryCode.transaction do
      user.two_factor_recovery_codes.destroy_all
      raw_codes.each do |raw_code|
        user.two_factor_recovery_codes.create!(code: raw_code)
      end
    end

    raw_codes
  end

  private

  def generate_raw_codes
    Set.new.tap do |codes|
      codes << random_code until codes.size == CODE_COUNT
    end.to_a
  end

  def random_code
    SecureRandom.alphanumeric(10).downcase.insert(5, "-")
  end
end
