class CreateImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :import_batches, comment: "User-owned transaction import batches" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this import batch"
      t.integer :status, null: false, default: 0, comment: "Import status code: pending, processing, imported, or failed"
      t.text :source_filename, null: false, default: "", comment: "Original uploaded file name or label"
      t.text :raw_csv, null: false, comment: "Raw CSV snapshot to import"
      t.integer :imported_count, null: false, default: 0, comment: "Number of imported transaction rows"
      t.text :error_message, null: false, default: "", comment: "User-facing import error message"
      t.timestamps null: false
    end

    add_index :import_batches, [ :user_id, :created_at ], name: "index_import_batches_on_owner_created_at"
    add_check_constraint :import_batches, "status IN (0,1,2,3)", name: "import_batches_status_valid"
  end
end
