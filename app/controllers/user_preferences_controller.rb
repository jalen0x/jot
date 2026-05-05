class UserPreferencesController < ApplicationController
  before_action :authenticate_user!

  # GET /user_preference
  def show
    authorize :user_preference
    @user_preference = find_or_build_preference
    load_default_account_options
  end

  # PATCH /user_preference
  def update
    authorize :user_preference
    @user_preference = find_or_build_preference
    assign_user_preference_attributes

    if @user_preference.errors.empty? && @user_preference.save
      redirect_to user_preference_path, notice: t(".updated")
    else
      load_default_account_options
      render :show, status: :unprocessable_content
    end
  end

  private

  def find_or_build_preference
    current_user.user_preference || current_user.build_user_preference(default_currency_code: "USD")
  end

  def user_preference_params
    params.expect(user_preference: [ :default_currency_code, :date_format, :default_account_id, :first_day_of_week, :locale, :number_format ])
  end

  def assign_user_preference_attributes
    attributes = user_preference_params.to_h.symbolize_keys
    default_account_provided = attributes.key?(:default_account_id)
    default_account_id = attributes.delete(:default_account_id)
    @user_preference.assign_attributes(attributes)
    assign_default_account(default_account_id) if default_account_provided
  end

  def assign_default_account(default_account_id)
    @user_preference.default_account = nil
    return if default_account_id.blank?

    account_id = Account.decode_prefix_id(default_account_id.to_s) || default_account_id
    @user_preference.default_account = current_user.accounts.kept.find(account_id)
  rescue ActiveRecord::RecordNotFound
    @user_preference.errors.add(:default_account, "is unavailable")
  end

  def load_default_account_options
    @default_account_options = current_user.accounts.kept.order(:display_order, :name)
  end
end
