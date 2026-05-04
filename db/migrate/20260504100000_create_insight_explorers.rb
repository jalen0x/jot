class CreateInsightExplorers < ActiveRecord::Migration[8.1]
  def change
    create_table :insight_explorers, comment: "User-owned saved insight explorer configurations" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this saved explorer"
      t.text :name, null: false, comment: "User-facing explorer name"
      t.jsonb :config, null: false, default: {}, comment: "Bounded inert chart and filter configuration"
      t.boolean :hidden, null: false, default: false, comment: "Whether this explorer is hidden from default lists"
      t.integer :display_order, null: false, default: 0, comment: "Owner-scoped sort order"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :insight_explorers, :discarded_at
    add_index :insight_explorers, [ :user_id, :display_order, :name ], name: "index_insight_explorers_on_owner_order_name"
    add_check_constraint :insight_explorers, "char_length(name) <= 64", name: "insight_explorers_name_length"
  end
end
