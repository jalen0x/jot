class CreateReceiptRecognitions < ActiveRecord::Migration[8.1]
  def change
    create_table :receipt_recognitions, comment: "User-owned receipt image recognition requests" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this receipt recognition request"
      t.integer :status, null: false, default: 0, comment: "Recognition lifecycle status: 0 pending, 1 processing, 2 succeeded, 3 failed"
      t.jsonb :result_json, null: false, default: {}, comment: "Parsed receipt fields returned by the recognition provider"
      t.text :error_message, null: true, comment: "Friendly failure message from the recognition lifecycle"
      t.timestamps null: false
    end

    add_check_constraint :receipt_recognitions,
      "status IN (0, 1, 2, 3)",
      name: "receipt_recognitions_status_valid"
  end
end
