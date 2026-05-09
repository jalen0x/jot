class ApplicationLockEnabler
  def enable(user:, current_password:, pin:, pin_confirmation:)
    lock = user.build_application_lock(pin: pin, pin_confirmation: pin_confirmation)

    unless user.valid_password?(current_password)
      lock.errors.add(:base, :current_password_invalid)
      return Result.new(enabled: false, application_lock: lock)
    end

    Result.new(enabled: lock.save, application_lock: lock)
  end

  class Result
    attr_reader :application_lock

    def initialize(enabled:, application_lock:)
      @enabled = enabled
      @application_lock = application_lock
    end

    def enabled? = @enabled
  end
end
