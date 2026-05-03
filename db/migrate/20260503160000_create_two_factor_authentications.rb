class CreateTwoFactorAuthentications < ActiveRecord::Migration[8.1]
  def change
    create_table :two_factor_authentications, comment: "User-owned TOTP two-factor settings" do |t|
      t.references :user, null: false, foreign_key: true, index: false, comment: "Owner of this two-factor setting"
      t.text :otp_secret, null: false, comment: "Base32 TOTP secret for authenticator apps"
      t.datetime :enabled_at, null: false, comment: "Time two-factor authentication was enabled"
      t.timestamps null: false
    end

    add_index :two_factor_authentications, :user_id, unique: true
  end
end
