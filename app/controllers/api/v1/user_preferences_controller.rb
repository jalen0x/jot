class Api::V1::UserPreferencesController < ApiController
  # GET /api/v1/user_preference
  def show
    authorize :user_preference

    render json: { user_preference: user_preference }
  end

  # PATCH/PUT /api/v1/user_preference
  def update
    authorize :user_preference
    assign_user_preference_attributes

    if user_preference.errors.empty? && user_preference.save
      render json: { user_preference: user_preference }
    else
      render json: { errors: user_preference.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def user_preference
    @user_preference ||= current_user.user_preference || current_user.build_user_preference(default_currency_code: "USD")
  end

  def user_preference_params
    params.expect(user_preference: [ :default_currency_code, :currency_display_format, :date_format, :default_account_id, :first_day_of_week, :fiscal_year_start_month, :fiscal_year_start_day, :fiscal_year_format, :locale, :number_format, :time_format ])
  end

  def assign_user_preference_attributes
    attributes = user_preference_params.to_h.symbolize_keys
    default_account_provided = attributes.key?(:default_account_id)
    default_account_id = attributes.delete(:default_account_id)
    user_preference.assign_attributes(attributes)
    assign_default_account(default_account_id) if default_account_provided
  end

  def assign_default_account(default_account_id)
    user_preference.default_account = nil
    return if default_account_id.blank?

    account_id = Account.decode_prefix_id(default_account_id.to_s) || default_account_id
    user_preference.default_account = current_user.accounts.kept.find(account_id)
  rescue ActiveRecord::RecordNotFound
    user_preference.errors.add(:default_account, "is unavailable")
  end
end
