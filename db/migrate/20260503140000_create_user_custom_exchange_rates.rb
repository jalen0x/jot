class CreateUserCustomExchangeRates < ActiveRecord::Migration[8.1]
  def change
    create_table :user_custom_exchange_rates, comment: "User-owned custom exchange rates" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this custom exchange rate"
      t.text :currency_code, null: false, comment: "ISO 4217 currency code for this override"
      t.bigint :rate_scaled, null: false, comment: "Exchange rate scaled by 100,000,000 relative to the user's default currency"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :user_custom_exchange_rates, :discarded_at
    add_index :user_custom_exchange_rates,
      [ :user_id, :currency_code ],
      unique: true,
      where: "discarded_at IS NULL",
      name: "index_user_custom_exchange_rates_on_active_owner_currency"
    add_check_constraint :user_custom_exchange_rates, "char_length(currency_code) = 3", name: "user_custom_exchange_rates_currency_code_length"
    add_check_constraint :user_custom_exchange_rates, "rate_scaled > 0", name: "user_custom_exchange_rates_rate_scaled_positive"
  end
end
