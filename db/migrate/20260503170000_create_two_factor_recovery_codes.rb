class CreateTwoFactorRecoveryCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :two_factor_recovery_codes, comment: "User-owned one-time 2FA recovery code digests" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this recovery code"
      t.text :code_digest, null: false, comment: "BCrypt digest of the raw recovery code"
      t.datetime :used_at, null: true, comment: "Time this recovery code was consumed"
      t.timestamps null: false
    end

    add_index :two_factor_recovery_codes, [ :user_id, :used_at ]
  end
end
