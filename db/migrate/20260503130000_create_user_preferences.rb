class CreateUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_preferences, comment: "User-owned display and ledger defaults" do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }, comment: "Owner of these preferences"
      t.text :default_currency_code, null: false, default: "USD", comment: "ISO 4217 default currency code for new ledger records"
      t.timestamps null: false
    end

    add_check_constraint :user_preferences, "char_length(default_currency_code) = 3", name: "user_preferences_default_currency_code_length"
  end
end
