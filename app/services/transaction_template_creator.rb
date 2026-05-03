class TransactionTemplateCreator
  def create_template(user:, attributes:, tag_ids:)
    attributes = attributes.to_h.symbolize_keys
    template = user.transaction_templates.build(template_attributes(user, attributes))
    tags = assign_owned_records(user, template, attributes, tag_ids)
    validate_business_rules(template)

    return Result.new(created: false, template: template) if template.errors.any? || !template.valid?

    ActiveRecord::Base.transaction do
      template.save!
      tags.each do |tag|
        template.transaction_template_taggings.create!(user: user, transaction_tag: tag)
      end
    end

    template.association(:transaction_tags).target = tags
    Result.new(created: true, template: template)
  end

  private

  def template_attributes(user, attributes)
    {
      template_kind: attributes[:template_kind],
      transaction_kind: attributes[:transaction_kind],
      name: attributes[:name],
      display_order: next_display_order(user, attributes[:template_kind]),
      source_amount_cents: attributes[:source_amount_cents].to_i,
      destination_amount_cents: attributes[:destination_amount_cents].to_i,
      hide_amount: ActiveModel::Type::Boolean.new.cast(attributes[:hide_amount]),
      comment: attributes[:comment],
      schedule_frequency: attributes[:schedule_frequency].presence || "disabled",
      schedule_rule: attributes[:schedule_rule],
      schedule_start_on: attributes[:schedule_start_on],
      schedule_end_on: attributes[:schedule_end_on],
      scheduled_at_minutes: attributes[:scheduled_at_minutes].to_i,
      timezone_utc_offset_minutes: attributes[:timezone_utc_offset_minutes].to_i
    }
  end

  def assign_owned_records(user, template, attributes, tag_ids)
    template.account = find_owned(user.accounts.kept, attributes[:account_id], template, :account)
    template.destination_account = find_owned(user.accounts.kept, attributes[:destination_account_id], template, :destination_account)
    template.transaction_category = find_owned(user.transaction_categories.kept, attributes[:transaction_category_id], template, :transaction_category)
    find_tags(user, tag_ids, template)
  end

  def find_owned(scope, id, template, field)
    return if id.blank?

    scope.find(decoded_id(scope, id))
  rescue ActiveRecord::RecordNotFound
    template.errors.add(field, "is unavailable")
    nil
  end

  def find_tags(user, tag_ids, template)
    requested_ids = Array(tag_ids).reject(&:blank?).map(&:to_s).uniq
    return [] if requested_ids.empty?

    tags = requested_ids.filter_map do |id|
      user.transaction_tags.kept.find(decoded_id(user.transaction_tags.kept, id))
    rescue ActiveRecord::RecordNotFound
      nil
    end
    template.errors.add(:transaction_tags, "include unavailable tags") if tags.size != requested_ids.size
    tags
  end

  def validate_business_rules(template)
    validate_category_type(template)
    validate_schedule_rule(template) if template.scheduled?
  end

  def validate_category_type(template)
    return if template.balance_adjustment? || template.transaction_category.blank?
    return if template.transaction_category.category_type == template.transaction_kind

    template.errors.add(:transaction_category, "does not match transaction type")
  end

  def validate_schedule_rule(template)
    if template.disabled? && template.schedule_rule.present?
      template.errors.add(:schedule_rule, "must be blank when schedule is disabled")
    elsif !template.disabled? && template.schedule_rule.blank?
      template.errors.add(:schedule_rule, "can't be blank when schedule is enabled")
    end
  end

  def next_display_order(user, template_kind)
    user.transaction_templates.kept.where(template_kind: template_kind).maximum(:display_order).to_i + 1
  end

  def decoded_id(scope, id)
    scope.klass.decode_prefix_id(id) || id
  end

  class Result
    attr_reader :template

    def initialize(created:, template:)
      @created = created
      @template = template
    end

    def created? = @created
  end
end
