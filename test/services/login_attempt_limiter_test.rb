require "test_helper"

class LoginAttemptLimiterTest < ActiveSupport::TestCase
  test "blocks after five failures for an IP or email within the window" do
    store = ActiveSupport::Cache::MemoryStore.new
    limiter = LoginAttemptLimiter.new(store: store)

    5.times do
      limiter.record_failure(email: "User@example.com", ip: "203.0.113.10")
    end

    assert limiter.blocked?(email: "user@example.com", ip: "203.0.113.10")
    assert limiter.blocked?(email: "user@example.com", ip: "203.0.113.11")
    assert limiter.blocked?(email: "other@example.com", ip: "203.0.113.10")
  end

  test "reset clears email and IP counters" do
    store = ActiveSupport::Cache::MemoryStore.new
    limiter = LoginAttemptLimiter.new(store: store)

    5.times do
      limiter.record_failure(email: "user@example.com", ip: "203.0.113.10")
    end
    limiter.reset(email: "user@example.com", ip: "203.0.113.10")

    refute limiter.blocked?(email: "user@example.com", ip: "203.0.113.10")
  end
end
