require "test_helper"

class LoginAttemptLimiterTest < ActiveSupport::TestCase
  setup { @limiter = LoginAttemptLimiter.new }

  test "blocks after five failures within the window" do
    5.times { @limiter.record_failure(email: "user@example.com", ip: "203.0.113.10") }
    assert @limiter.blocked?(email: "user@example.com", ip: "203.0.113.10")
  end

  test "fewer than five failures stay below the threshold" do
    4.times { @limiter.record_failure(email: "user@example.com", ip: "203.0.113.10") }
    refute @limiter.blocked?(email: "user@example.com", ip: "203.0.113.10")
  end

  test "email counter blocks across IPs" do
    5.times { @limiter.record_failure(email: "user@example.com", ip: "203.0.113.10") }
    assert @limiter.blocked?(email: "user@example.com", ip: "198.51.100.99")
  end

  test "ip counter blocks across emails" do
    5.times { @limiter.record_failure(email: "user@example.com", ip: "203.0.113.10") }
    assert @limiter.blocked?(email: "other@example.com", ip: "203.0.113.10")
  end

  test "email is normalised when keyed" do
    5.times { @limiter.record_failure(email: "  USER@example.com  ", ip: "203.0.113.10") }
    assert @limiter.blocked?(email: "user@example.com", ip: "198.51.100.99")
  end

  test "reset clears both email and ip counters" do
    5.times { @limiter.record_failure(email: "user@example.com", ip: "203.0.113.10") }
    @limiter.reset(email: "user@example.com", ip: "203.0.113.10")

    refute @limiter.blocked?(email: "user@example.com", ip: "203.0.113.10")
    refute @limiter.blocked?(email: "user@example.com", ip: "198.51.100.99")
    refute @limiter.blocked?(email: "other@example.com", ip: "203.0.113.10")
  end
end
