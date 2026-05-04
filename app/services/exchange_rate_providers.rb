module ExchangeRateProviders
  FetchError = Class.new(StandardError)
  UnsupportedProviderError = Class.new(StandardError)

  RateSet = Data.define(:data_source, :reference_url, :base_currency_code, :observed_at, :rates)
  Rate = Data.define(:currency_code, :rate)

  def self.fetch(provider_key)
    case provider_key.to_s
    when "bank_of_canada"
      BankOfCanada.new
    else
      raise UnsupportedProviderError, "Unsupported exchange-rate provider: #{provider_key}"
    end
  end
end
