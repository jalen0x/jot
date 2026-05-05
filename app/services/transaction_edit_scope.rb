class TransactionEditScope
  def editable?(transaction:, current_time: Time.current)
    case edit_scope(transaction)
    when "all"
      true
    when "none"
      false
    when "today_or_later"
      transaction.transacted_at >= current_time.beginning_of_day
    when "last_24_hours_or_later"
      transaction.transacted_at > current_time - 24.hours
    when "this_week_or_later"
      transaction.transacted_at >= week_start_for(transaction, current_time)
    when "this_month_or_later"
      transaction.transacted_at >= current_time.beginning_of_month
    when "this_year_or_later"
      transaction.transacted_at >= current_time.beginning_of_year
    else
      false
    end
  end

  private

  def edit_scope(transaction)
    transaction.user.user_preference&.transaction_edit_scope || UserPreference::DEFAULT_TRANSACTION_EDIT_SCOPE
  end

  def week_start_for(transaction, current_time)
    first_day_of_week = transaction.user.user_preference&.first_day_of_week || 0
    days_since_week_start = (current_time.wday - first_day_of_week) % 7
    current_time.beginning_of_day - days_since_week_start.days
  end
end
