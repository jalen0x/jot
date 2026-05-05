class TransactionCategoryDiscarder
  def discard_category(category:)
    ActiveRecord::Base.transaction do
      now = Time.current
      category.user.transaction_categories.kept
        .where(parent_category: category)
        .update_all(discarded_at: now, updated_at: now)
      category.discard!
    end

    nil
  end
end
