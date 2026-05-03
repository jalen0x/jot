class CreateTransactionTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_templates, comment: "User-owned transaction templates and schedules" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this template"
      t.references :account, null: false, foreign_key: true, index: true, comment: "Source account for generated transactions"
      t.references :destination_account, null: true, foreign_key: { to_table: :accounts }, index: true, comment: "Destination account for transfer templates"
      t.references :transaction_category, null: true, foreign_key: true, index: true, comment: "Category for generated transactions"
      t.integer :template_kind, null: false, comment: "Template kind code: normal or scheduled"
      t.integer :transaction_kind, null: false, comment: "Generated transaction kind code"
      t.text :name, null: false, comment: "Human-readable template name"
      t.integer :display_order, null: false, default: 0, comment: "User-controlled display order"
      t.integer :source_amount_cents, null: false, default: 0, comment: "Source amount in cents"
      t.integer :destination_amount_cents, null: false, default: 0, comment: "Destination amount in cents for transfers"
      t.boolean :hide_amount, null: false, default: false, comment: "Whether generated transaction amount is hidden"
      t.text :comment, null: false, default: "", comment: "Optional generated transaction note"
      t.integer :schedule_frequency, null: false, default: 0, comment: "Schedule frequency code"
      t.text :schedule_rule, null: false, default: "", comment: "Frequency-specific schedule rule"
      t.date :schedule_start_on, null: true, comment: "First date this schedule may run"
      t.date :schedule_end_on, null: true, comment: "Last date this schedule may run"
      t.integer :scheduled_at_minutes, null: false, default: 0, comment: "Minute of local day to run scheduled template"
      t.integer :timezone_utc_offset_minutes, null: false, default: 0, comment: "Template timezone UTC offset in minutes"
      t.boolean :hidden, null: false, default: false, comment: "Whether the template is hidden in normal lists"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :transaction_templates, :discarded_at
    add_index :transaction_templates, [ :user_id, :template_kind, :display_order ], name: "index_transaction_templates_on_owner_kind_order"
    add_index :transaction_templates, [ :discarded_at, :template_kind, :schedule_frequency, :schedule_start_on, :schedule_end_on ], name: "index_transaction_templates_on_schedule_lookup"
    add_check_constraint :transaction_templates, "template_kind IN (1,2)", name: "transaction_templates_template_kind_valid"
    add_check_constraint :transaction_templates, "transaction_kind IN (1,2,3,4)", name: "transaction_templates_transaction_kind_valid"
    add_check_constraint :transaction_templates, "schedule_frequency IN (0,1,2,3,4)", name: "transaction_templates_schedule_frequency_valid"
    add_check_constraint :transaction_templates, "scheduled_at_minutes BETWEEN 0 AND 1439", name: "transaction_templates_scheduled_at_minutes_range"
    add_check_constraint :transaction_templates, "timezone_utc_offset_minutes BETWEEN -720 AND 840", name: "transaction_templates_timezone_offset_range"
    add_check_constraint :transaction_templates, "destination_account_id IS NULL OR destination_account_id <> account_id", name: "transaction_templates_destination_account_differs"

    create_table :transaction_template_taggings, comment: "Join table between transaction templates and tags" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this template tagging"
      t.references :transaction_template, null: false, foreign_key: true, index: true, comment: "Tagged transaction template"
      t.references :transaction_tag, null: false, foreign_key: true, index: true, comment: "Applied transaction tag"
      t.timestamps null: false
    end

    add_index :transaction_template_taggings, [ :transaction_template_id, :transaction_tag_id ], unique: true, name: "index_template_taggings_on_template_and_tag"
  end
end
