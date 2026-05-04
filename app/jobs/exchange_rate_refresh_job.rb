class ExchangeRateRefreshJob < ApplicationJob
  retry_on ExchangeRateProviders::FetchError, Net::OpenTimeout, Net::ReadTimeout, SocketError, wait: :polynomially_longer, attempts: 5

  def perform(provider_key)
    ExchangeRateUpdater.new.refresh_rates(provider_key: provider_key)
  end
end
