class Api::V1::TransactionCategoriesController < ApiController
  # GET /api/v1/transaction_categories
  def index
    authorize TransactionCategory
    categories = policy_scope(TransactionCategory).kept.order(:category_type, :display_order, :name)

    render json: { transaction_categories: categories.map(&:as_json) }
  end
end
