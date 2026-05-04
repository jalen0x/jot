class LoginAttemptLimiter
  LIMIT = 5
  WINDOW = 1.minute

  class << self
    attr_writer :store

    def store
      @store || Rails.cache
    end
  end

  def initialize(store: self.class.store)
    @store = store
  end

  def blocked?(email:, ip:)
    keys_for(email:, ip:).any? { |key| @store.read(key).to_i >= LIMIT }
  end

  def record_failure(email:, ip:)
    keys_for(email:, ip:).each do |key|
      @store.increment(key, 1, expires_in: WINDOW)
    end
  end

  def reset(email:, ip:)
    keys_for(email:, ip:).each do |key|
      @store.delete(key)
    end
  end

  private

  def keys_for(email:, ip:)
    identities = []
    identities << "email:#{email.to_s.downcase.strip}" if email.present?
    identities << "ip:#{ip}" if ip.present?
    identities.map { |identity| "login-attempts:#{Digest::SHA256.hexdigest(identity)}" }
  end
end
