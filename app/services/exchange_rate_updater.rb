class ExchangeRateUpdater
  Result = Data.define(:snapshots) do
    def snapshot_count = snapshots.size
  end

  def refresh_rates(provider_key:)
    rate_set = ExchangeRateProviders.fetch(provider_key).fetch_latest
    snapshots = persist_snapshots(rate_set)

    Result.new(snapshots: snapshots)
  end

  private

  def persist_snapshots(rate_set)
    snapshots = []

    ActiveRecord::Base.transaction do
      rate_set.rates.each do |rate|
        snapshot = ExchangeRateSnapshot.find_or_initialize_by(
          data_source: rate_set.data_source,
          base_currency_code: rate_set.base_currency_code,
          currency_code: rate.currency_code,
          observed_at: rate_set.observed_at
        )
        snapshot.reference_url = rate_set.reference_url
        snapshot.rate = rate.rate
        snapshot.save!
        snapshots << snapshot
      end
    end

    snapshots
  end
end
