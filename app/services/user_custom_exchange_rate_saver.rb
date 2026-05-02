class UserCustomExchangeRateSaver
  def save_rate(user:, attributes:)
    attributes = attributes.to_h.symbolize_keys
    currency_code = attributes[:currency_code].to_s.strip.upcase
    exchange_rate = user.user_custom_exchange_rates.kept.find_or_initialize_by(currency_code: currency_code)
    exchange_rate.rate = attributes[:rate]

    Result.new(saved: exchange_rate.save, exchange_rate: exchange_rate)
  end

  class Result
    attr_reader :exchange_rate

    def initialize(saved:, exchange_rate:)
      @saved = saved
      @exchange_rate = exchange_rate
    end

    def saved? = @saved
  end
end
