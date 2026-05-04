class AddDefaultAccountToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_reference :user_preferences,
      :default_account,
      null: true,
      foreign_key: { to_table: :accounts },
      comment: "User account selected by default on new transaction forms"
  end
end
