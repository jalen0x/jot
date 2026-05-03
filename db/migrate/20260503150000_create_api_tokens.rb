class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens, comment: "User-owned API token digests" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this API token"
      t.text :name, null: false, comment: "User-facing token name"
      t.text :token_digest, null: false, comment: "BCrypt digest of the raw token"
      t.datetime :last_used_at, null: true, comment: "Last successful authentication time"
      t.datetime :expires_at, null: true, comment: "Optional expiration time"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :api_tokens, :discarded_at
    add_index :api_tokens, :expires_at
    add_index :api_tokens, [ :user_id, :discarded_at ], name: "index_api_tokens_on_owner_discarded_at"
  end
end
