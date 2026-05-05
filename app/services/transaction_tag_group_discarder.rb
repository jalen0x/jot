class TransactionTagGroupDiscarder
  def discard_tag_group(tag_group:)
    ActiveRecord::Base.transaction do
      now = Time.current
      tag_group.user.transaction_tags.kept
        .where(transaction_tag_group: tag_group)
        .update_all(discarded_at: now, updated_at: now)
      tag_group.discard!
    end

    nil
  end
end
