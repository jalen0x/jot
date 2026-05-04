class TransactionCategoryUpdater
  def update_category(category:, attributes:)
    attributes = attributes.to_h.symbolize_keys
    category.assign_attributes(category_attributes(attributes))
    category.parent_category = parent_category_for(category, attributes[:parent_category_id])

    return Result.new(updated: false, category: category) if category.errors.any? || !category.valid?

    category.save!
    Result.new(updated: true, category: category)
  end

  private

  def category_attributes(attributes)
    {
      name: attributes[:name],
      category_type: attributes[:category_type],
      icon_key: attributes[:icon_key],
      color_hex: attributes[:color_hex],
      comment: attributes[:comment],
      hidden: ActiveModel::Type::Boolean.new.cast(attributes[:hidden])
    }
  end

  def parent_category_for(category, parent_category_id)
    return if parent_category_id.blank?

    parent_category = category.user.transaction_categories.kept.find(decoded_id(category.user.transaction_categories.kept, parent_category_id))
    return parent_category unless parent_category == category

    category.errors.add(:parent_category, "cannot be itself")
    nil
  rescue ActiveRecord::RecordNotFound
    category.errors.add(:parent_category, "is unavailable")
    nil
  end

  def decoded_id(scope, id)
    scope.klass.decode_prefix_id(id) || id
  end

  class Result
    attr_reader :category

    def initialize(updated:, category:)
      @updated = updated
      @category = category
    end

    def updated? = @updated
  end
end
