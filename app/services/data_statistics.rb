class DataStatistics
  def summarize_user_data(user:)
    Result.new(
      account_count: user.accounts.kept.count,
      transaction_category_count: user.transaction_categories.kept.count,
      transaction_tag_count: user.transaction_tags.kept.count,
      transaction_count: user.transactions.kept.count,
      transaction_picture_count: user.transactions.kept.joins(:pictures_attachments).count,
      insight_explorer_count: user.insight_explorers.kept.count,
      transaction_template_count: user.transaction_templates.kept.normal.count,
      scheduled_transaction_count: user.transaction_templates.kept.scheduled.count
    )
  end

  class Result
    attr_reader :account_count, :transaction_category_count, :transaction_tag_count,
      :transaction_count, :transaction_picture_count, :insight_explorer_count,
      :transaction_template_count, :scheduled_transaction_count

    def initialize(
      account_count:,
      transaction_category_count:,
      transaction_tag_count:,
      transaction_count:,
      transaction_picture_count:,
      insight_explorer_count:,
      transaction_template_count:,
      scheduled_transaction_count:
    )
      @account_count = account_count
      @transaction_category_count = transaction_category_count
      @transaction_tag_count = transaction_tag_count
      @transaction_count = transaction_count
      @transaction_picture_count = transaction_picture_count
      @insight_explorer_count = insight_explorer_count
      @transaction_template_count = transaction_template_count
      @scheduled_transaction_count = scheduled_transaction_count
    end
  end
end
