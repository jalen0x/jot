class TransactionTagUpdater
  def update_tag(tag:, attributes:)
    attributes = attributes.to_h.symbolize_keys
    tag.assign_attributes(tag_attributes(attributes))
    tag.transaction_tag_group = transaction_tag_group_for(tag, attributes[:transaction_tag_group_id])

    return Result.new(updated: false, tag: tag) if tag.errors.any? || !tag.valid?

    tag.save!
    Result.new(updated: true, tag: tag)
  end

  private

  def tag_attributes(attributes)
    tag_attributes = {
      name: attributes[:name],
      hidden: ActiveModel::Type::Boolean.new.cast(attributes[:hidden])
    }
    tag_attributes[:display_order] = attributes[:display_order] if attributes.key?(:display_order)
    tag_attributes
  end

  def transaction_tag_group_for(tag, group_id)
    return if group_id.blank?

    tag.user.transaction_tag_groups.kept.find(decoded_id(tag.user.transaction_tag_groups.kept, group_id))
  rescue ActiveRecord::RecordNotFound
    tag.errors.add(:transaction_tag_group, "is unavailable")
    nil
  end

  def decoded_id(scope, id)
    scope.klass.decode_prefix_id(id) || id
  end

  class Result
    attr_reader :tag

    def initialize(updated:, tag:)
      @updated = updated
      @tag = tag
    end

    def updated? = @updated
  end
end
