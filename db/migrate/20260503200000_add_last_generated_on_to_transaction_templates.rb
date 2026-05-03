class AddLastGeneratedOnToTransactionTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :transaction_templates, :last_generated_on, :date, null: true, comment: "Template-local date that last generated a transaction"
  end
end
