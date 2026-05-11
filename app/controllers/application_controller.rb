class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  before_action :require_application_unlock
  helper_method :application_lock_unlocked?, :application_lock_unlocked_or_disabled?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :switch_locale

  private

  def switch_locale(&action)
    I18n.with_locale(preferred_locale, &action)
  end

  def preferred_locale
    warden.user(:user)&.user_preference&.locale.presence || I18n.default_locale
  end

  def require_application_unlock
    user = warden.user(:user)
    return if user.blank?
    return unless user.application_lock_enabled?
    return if application_lock_unlocked?

    redirect_to new_application_lock_session_path, alert: t("application_locks.locked_alert")
  end

  def application_lock_unlocked?
    session[:application_lock_unlocked_user_id] == warden.user(:user)&.id
  end

  def application_lock_unlocked_or_disabled?
    return true unless user_signed_in?
    return true unless current_user.application_lock_enabled?

    application_lock_unlocked?
  end

  def mark_application_unlocked
    session[:application_lock_unlocked_user_id] = current_user.id
  end

  def clear_application_unlock
    session.delete(:application_lock_unlocked_user_id)
  end

  def ledger_filter_params(include_amounts: false, include_dates: false)
    filters = {
      transaction_kind: params[:transaction_kind],
      account_id: params[:account_id],
      transaction_category_id: params[:transaction_category_id],
      tag_id: params[:tag_id],
      keyword: params[:keyword]
    }.compact

    filters[:account_ids] = array_param(:account_ids) if param_key?(params, :account_ids)
    filters[:transaction_category_ids] = array_param(:transaction_category_ids) if param_key?(params, :transaction_category_ids)
    tag_filters = tag_filter_params
    filters[:tag_filter] = tag_filters if tag_filters
    filters[:minimum_amount_cents] = params[:minimum_amount_cents] if include_amounts
    filters[:maximum_amount_cents] = params[:maximum_amount_cents] if include_amounts
    filters[:start_date] = params[:start_date] if include_dates
    filters[:end_date] = params[:end_date] if include_dates
    filters
  end

  def tag_filter_params
    tag_filter = params[:tag_filter]
    return unless tag_filter.is_a?(ActionController::Parameters) || tag_filter.is_a?(Hash)

    filters = { without_tags: tag_filter[:without_tags] }.compact
    filters[:include_any_ids] = array_param(:include_any_ids, source: tag_filter) if param_key?(tag_filter, :include_any_ids)
    filters[:include_all_ids] = array_param(:include_all_ids, source: tag_filter) if param_key?(tag_filter, :include_all_ids)
    filters[:exclude_any_ids] = array_param(:exclude_any_ids, source: tag_filter) if param_key?(tag_filter, :exclude_any_ids)
    filters[:exclude_all_ids] = array_param(:exclude_all_ids, source: tag_filter) if param_key?(tag_filter, :exclude_all_ids)
    filters
  end

  def array_param(key, source: params)
    Array(source[key]).reject(&:blank?)
  end

  def param_key?(source, key)
    source.key?(key) || source.key?(key.to_s)
  end
end
