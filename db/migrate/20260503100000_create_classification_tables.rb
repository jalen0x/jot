class CreateClassificationTables < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_categories, comment: "User-owned transaction categories" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this category"
      t.references :parent_category, null: true, foreign_key: { to_table: :transaction_categories }, index: true, comment: "Parent category for two-level category hierarchies"
      t.integer :category_type, null: false, comment: "Category type code: income, expense, or transfer"
      t.text :name, null: false, comment: "Human-readable category name"
      t.integer :display_order, null: false, default: 0, comment: "User-controlled display order"
      t.integer :icon_key, null: false, comment: "Icon identifier from the category icon catalog"
      t.text :color_hex, null: false, comment: "Six-character RGB hex color without #"
      t.boolean :hidden, null: false, default: false, comment: "Whether the category is hidden in normal lists"
      t.text :comment, null: false, default: "", comment: "Optional user note"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :transaction_categories, :discarded_at
    add_index :transaction_categories, [ :user_id, :category_type, :parent_category_id, :display_order ], name: "index_transaction_categories_on_owner_type_parent_order"
    add_check_constraint :transaction_categories, "category_type IN (1,2,3)", name: "transaction_categories_type_valid"
    add_check_constraint :transaction_categories, "char_length(color_hex) = 6", name: "transaction_categories_color_hex_length"
    add_check_constraint :transaction_categories, "parent_category_id IS NULL OR parent_category_id <> id", name: "transaction_categories_parent_not_self"

    create_table :transaction_tag_groups, comment: "User-owned transaction tag groups" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this tag group"
      t.text :name, null: false, comment: "Human-readable tag group name"
      t.integer :display_order, null: false, default: 0, comment: "User-controlled display order"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :transaction_tag_groups, :discarded_at
    add_index :transaction_tag_groups, [ :user_id, :display_order ], name: "index_transaction_tag_groups_on_owner_order"

    create_table :transaction_tags, comment: "User-owned transaction tags" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this tag"
      t.references :transaction_tag_group, null: true, foreign_key: true, index: true, comment: "Optional tag group"
      t.text :name, null: false, comment: "Human-readable tag name"
      t.integer :display_order, null: false, default: 0, comment: "User-controlled display order"
      t.boolean :hidden, null: false, default: false, comment: "Whether the tag is hidden in normal lists"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :transaction_tags, :discarded_at
    add_index :transaction_tags, [ :user_id, :transaction_tag_group_id, :display_order ], name: "index_transaction_tags_on_owner_group_order"

    create_table :transaction_taggings, comment: "Join table between transactions and tags" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this tagging"
      t.references :transaction, null: false, foreign_key: true, index: true, comment: "Tagged transaction"
      t.references :transaction_tag, null: false, foreign_key: true, index: true, comment: "Applied transaction tag"
      t.timestamps null: false
    end

    add_index :transaction_taggings, [ :transaction_id, :transaction_tag_id ], unique: true, name: "index_transaction_taggings_on_transaction_and_tag"
  end
end
