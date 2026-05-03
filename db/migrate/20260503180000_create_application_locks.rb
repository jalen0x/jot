class CreateApplicationLocks < ActiveRecord::Migration[8.1]
  def change
    create_table :application_locks, comment: "User-owned application lock PIN digests" do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }, comment: "Owner of this application lock"
      t.text :pin_digest, null: false, comment: "BCrypt digest of the application lock PIN"
      t.timestamps null: false
    end
  end
end
