class ApplicationLockDisabler
  def disable(user:, current_password:)
    lock = user.application_lock

    unless user.valid_password?(current_password)
      lock.errors.add(:base, :current_password_invalid)
      return Result.new(disabled: false, application_lock: lock)
    end

    lock.destroy!
    Result.new(disabled: true, application_lock: lock)
  end

  class Result
    attr_reader :application_lock

    def initialize(disabled:, application_lock:)
      @disabled = disabled
      @application_lock = application_lock
    end

    def disabled? = @disabled
  end
end
