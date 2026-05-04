class Api::V1::TransactionCategoriesController < ApiController
  # GET /api/v1/transaction_categories
  def index
    authorize TransactionCategory
    categories = policy_scope(TransactionCategory).kept.order(:category_type, :display_order, :name)

    render json: { transaction_categories: categories.map(&:as_json) }
  end

  # GET /api/v1/transaction_categories/:id
  def show
    category = scoped_category
    authorize category

    render json: { transaction_category: category.as_json }
  end

  # POST /api/v1/transaction_categories
  def create
    authorize TransactionCategory
    category = current_user.transaction_categories.build(category_params.except(:parent_category_id))
    category.parent_category = parent_category_for(category)
    category.display_order = next_display_order(category.parent_category)

    if category.errors.empty? && category.save
      render json: { transaction_category: category.as_json }, status: :created
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/v1/transaction_categories/:id
  def update
    category = scoped_category
    authorize category
    result = TransactionCategoryUpdater.new.update_category(category: category, attributes: category_params)

    if result.updated?
      render json: { transaction_category: result.category.as_json }
    else
      render json: { errors: result.category.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/transaction_categories/:id
  def destroy
    category = scoped_category
    authorize category
    category.discard!

    head :no_content
  end

  private

  def category_params
    @category_params ||= params.expect(transaction_category: [ :name, :category_type, :parent_category_id, :icon_key, :color_hex, :comment, :hidden, :display_order ])
  end

  def parent_category_for(category)
    parent_category_id = category_params[:parent_category_id]
    return if parent_category_id.blank?

    current_user.transaction_categories.kept.find(TransactionCategory.decode_prefix_id(parent_category_id) || parent_category_id)
  rescue ActiveRecord::RecordNotFound
    category.errors.add(:parent_category, "is unavailable")
    nil
  end

  def next_display_order(parent_category)
    current_user.transaction_categories.kept.where(parent_category: parent_category).maximum(:display_order).to_i + 1
  end

  def scoped_category
    policy_scope(TransactionCategory).kept.find(params[:id])
  end
end
