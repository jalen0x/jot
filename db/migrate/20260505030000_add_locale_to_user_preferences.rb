class AddLocaleToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :locale, :text, null: false, default: "en", comment: "I18n locale used for signed-in interface text"

    add_check_constraint :user_preferences, "locale IN ('en', 'zh-CN')", name: "user_preferences_locale_supported"
  end
end
