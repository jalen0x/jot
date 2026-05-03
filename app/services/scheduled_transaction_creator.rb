class ScheduledTransactionCreator
  Result = Data.define(:transactions, :skipped_count) do
    def created_count = transactions.size
  end

  def initialize(transaction_recorder: TransactionRecorder.new)
    @transaction_recorder = transaction_recorder
  end

  def create_due_transactions(current_time: Time.current)
    transactions = []
    skipped_count = 0

    due_candidate_scope.find_each do |template|
      template.with_lock do
        if due?(template, current_time)
          transactions << record_transaction(template, current_time)
        else
          skipped_count += 1
        end
      end
    end

    Result.new(transactions:, skipped_count:)
  end

  private

  attr_reader :transaction_recorder

  def due_candidate_scope
    TransactionTemplate.kept.scheduled.where.not(schedule_frequency: :disabled).includes(:transaction_tags)
  end

  def due?(template, current_time)
    local_date = local_schedule_date(template, current_time)
    return false if template.last_generated_on == local_date
    return false if template.schedule_start_on.present? && local_date < template.schedule_start_on
    return false if template.schedule_end_on.present? && local_date > template.schedule_end_on
    return false if local_minutes(template, current_time) < template.scheduled_at_minutes

    due_on_frequency?(template, local_date)
  end

  def due_on_frequency?(template, local_date)
    values = schedule_values(template.schedule_rule)
    return false if values.empty?

    case template.schedule_frequency
    when "daily"
      true
    when "weekly"
      values.include?(local_date.wday)
    when "monthly"
      monthly_days(values, local_date).include?(local_date.day)
    when "yearly"
      values.include?(local_date.month * 100 + local_date.day)
    else
      false
    end
  end

  def record_transaction(template, current_time)
    result = transaction_recorder.record_transaction(
      user: template.user,
      attributes: transaction_attributes(template, current_time),
      tag_ids: template.transaction_tags.ids
    )

    raise ActiveRecord::RecordInvalid.new(result.transaction) unless result.recorded?

    template.update!(last_generated_on: local_schedule_date(template, current_time))
    result.transaction
  end

  def transaction_attributes(template, current_time)
    {
      transaction_kind: template.transaction_kind,
      account_id: template.account_id,
      destination_account_id: template.destination_account_id,
      transaction_category_id: template.transaction_category_id,
      transacted_at: scheduled_transaction_time(template, current_time),
      timezone_utc_offset_minutes: template.timezone_utc_offset_minutes,
      source_amount_cents: template.source_amount_cents,
      destination_amount_cents: template.destination_amount_cents,
      hide_amount: template.hide_amount,
      comment: template.comment
    }
  end

  def scheduled_transaction_time(template, current_time)
    local_date = local_schedule_date(template, current_time)
    Time.utc(local_date.year, local_date.month, local_date.day) + template.scheduled_at_minutes.minutes - template.timezone_utc_offset_minutes.minutes
  end

  def local_schedule_date(template, current_time)
    (current_time.to_time.utc + template.timezone_utc_offset_minutes.minutes).to_date
  end

  def local_minutes(template, current_time)
    local_time = current_time.to_time.utc + template.timezone_utc_offset_minutes.minutes
    (local_time.hour * 60) + local_time.min
  end

  def monthly_days(values, local_date)
    last_day = Date.new(local_date.year, local_date.month, -1).day
    values.map { |value| value.negative? ? last_day + value + 1 : value }
  end

  def schedule_values(rule)
    parts = rule.to_s.split(",").map(&:strip).reject(&:blank?)
    return [] if parts.empty?

    values = parts.map do |part|
      Integer(part, exception: false)
    end
    return [] if values.any?(&:nil?)

    values
  end
end
