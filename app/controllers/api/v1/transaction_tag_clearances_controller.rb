class Api::V1::TransactionTagClearancesController < ApiController
  # POST /api/v1/transaction_tag_clearances
  def create
    authorize :transaction_tag_clearance
    TransactionBatchTagClearer.new.clear_tags(transactions: transactions)

    head :no_content
  end

  private

  def transactions
    transaction_ids.map do |id|
      policy_scope(Transaction).kept.find(Transaction.decode_prefix_id(id) || id)
    end
  end

  def transaction_ids
    Array(params.permit(transaction_ids: [])[:transaction_ids]).reject(&:blank?).map(&:to_s).uniq
  end
end
