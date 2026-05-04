class ExchangeRateCatalog
  BASE_CURRENCY_CODE = "USD"
  BASE_RATE = "1"

  Catalog = Data.define(:base_currency_code, :exchange_rates) do
    def as_json(_options = {})
      {
        base_currency_code: base_currency_code,
        exchange_rates: exchange_rates.map(&:as_json)
      }
    end
  end

  Rate = Data.define(:currency_code, :rate) do
    def as_json(_options = {})
      {
        currency_code: currency_code,
        rate: rate
      }
    end
  end

  def latest_rates(user:)
    base_currency_code = default_currency_code(user)
    rates_by_currency = provider_rates(base_currency_code).index_by(&:currency_code)
    user.user_custom_exchange_rates.kept.order(:currency_code).each do |exchange_rate|
      rates_by_currency[exchange_rate.currency_code] = Rate.new(currency_code: exchange_rate.currency_code, rate: exchange_rate.rate.to_s("F"))
    end
    rates_by_currency[base_currency_code] = Rate.new(currency_code: base_currency_code, rate: BASE_RATE)

    Catalog.new(base_currency_code: base_currency_code, exchange_rates: rates_by_currency.values.sort_by(&:currency_code))
  end

  private

  def provider_rates(base_currency_code)
    ExchangeRateSnapshot.latest_for_base(base_currency_code).map do |exchange_rate|
      Rate.new(currency_code: exchange_rate.currency_code, rate: exchange_rate.rate.to_s("F"))
    end
  end

  def default_currency_code(user)
    user.user_preference&.default_currency_code || BASE_CURRENCY_CODE
  end
end
