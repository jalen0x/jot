class CreateExchangeRateSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_rate_snapshots, comment: "Provider-observed automatic exchange rate snapshots" do |t|
      t.text :data_source, null: false, comment: "Provider key or human-readable data source name"
      t.text :reference_url, null: true, comment: "Provider reference URL for this rate set"
      t.text :base_currency_code, null: false, comment: "ISO 4217 currency code that rates are based on"
      t.text :currency_code, null: false, comment: "ISO 4217 target currency code"
      t.bigint :rate_scaled, null: false, comment: "Exchange rate scaled by UserCustomExchangeRate::SCALE"
      t.datetime :observed_at, null: false, comment: "Time the provider says this rate was observed or published"
      t.timestamps null: false
    end

    add_index :exchange_rate_snapshots,
      [ :base_currency_code, :currency_code, :observed_at ],
      name: "index_exchange_rate_snapshots_on_base_currency_observed_at"
    add_index :exchange_rate_snapshots,
      [ :data_source, :base_currency_code, :currency_code, :observed_at ],
      unique: true,
      name: "index_exchange_rate_snapshots_on_provider_observation"

    add_check_constraint :exchange_rate_snapshots, "char_length(base_currency_code) = 3", name: "exchange_rate_snapshots_base_currency_code_length"
    add_check_constraint :exchange_rate_snapshots, "char_length(currency_code) = 3", name: "exchange_rate_snapshots_currency_code_length"
    add_check_constraint :exchange_rate_snapshots, "base_currency_code <> currency_code", name: "exchange_rate_snapshots_distinct_currencies"
    add_check_constraint :exchange_rate_snapshots, "rate_scaled > 0", name: "exchange_rate_snapshots_rate_scaled_positive"
  end
end
