require "json"
require "net/http"

class ExchangeRateProviders::BankOfCanada
  URL = "https://www.bankofcanada.ca/valet/observations/group/FX_RATES_DAILY/json?recent=1"
  DATA_SOURCE = "Bank of Canada"
  REFERENCE_URL = "https://www.bankofcanada.ca/rates/exchange/daily-exchange-rates/"
  BASE_CURRENCY_CODE = "CAD"
  OBSERVED_AT_ZONE = "America/Toronto"

  def fetch_latest
    response = Net::HTTP.get_response(URI(URL))
    raise ExchangeRateProviders::FetchError, "Bank of Canada returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    parse(JSON.parse(response.body))
  rescue JSON::ParserError => error
    raise ExchangeRateProviders::FetchError, error.message
  end

  private

  def parse(payload)
    observations = Array(payload.fetch("observations"))
    latest_observation = observations.max_by { |observation| observation["d"].to_s }
    raise ExchangeRateProviders::FetchError, "Bank of Canada response has no observations" if latest_observation.blank?

    ExchangeRateProviders::RateSet.new(
      data_source: DATA_SOURCE,
      reference_url: REFERENCE_URL,
      base_currency_code: BASE_CURRENCY_CODE,
      observed_at: observed_at(latest_observation.fetch("d")),
      rates: rates_from(latest_observation)
    )
  rescue KeyError => error
    raise ExchangeRateProviders::FetchError, error.message
  end

  def rates_from(observation)
    observation.filter_map do |key, value|
      match = key.match(/\AFX([A-Z]{3})#{BASE_CURRENCY_CODE}\z/)
      next if match.blank?

      rate = BigDecimal(value.fetch("v"))
      next unless rate.positive?

      ExchangeRateProviders::Rate.new(currency_code: match[1], rate: BigDecimal("1") / rate)
    rescue ArgumentError, KeyError, NoMethodError
      nil
    end
  end

  def observed_at(date)
    Time.find_zone!(OBSERVED_AT_ZONE).parse("#{date} 16:30")
  end
end
