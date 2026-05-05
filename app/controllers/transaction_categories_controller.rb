class TransactionCategoriesController < ApplicationController
  before_action :authenticate_user!

  # GET /transaction_categories
  def index
    authorize TransactionCategory
    @transaction_categories = policy_scope(TransactionCategory).kept.where(parent_category_id: nil).order(:category_type, :display_order, :name)
    @sub_categories_by_parent_id = policy_scope(TransactionCategory).kept
      .where(parent_category_id: @transaction_categories.select(:id))
      .order(:category_type, :display_order, :name)
      .group_by(&:parent_category_id)
  end

  # GET /transaction_categories/new
  def new
    @transaction_category = current_user.transaction_categories.build(default_category_attributes)
    @parent_category_options = parent_category_options
    authorize @transaction_category
  end

  # POST /transaction_categories
  def create
    authorize TransactionCategory
    @transaction_category = current_user.transaction_categories.build(category_params.except(:parent_category_id))
    @transaction_category.parent_category = parent_category_for(@transaction_category)
    @transaction_category.display_order = next_display_order(@transaction_category.parent_category)

    if @transaction_category.errors.empty? && @transaction_category.save
      redirect_to transaction_categories_path, notice: "Category created."
    else
      @parent_category_options = parent_category_options
      render :new, status: :unprocessable_content
    end
  end

  # GET /transaction_categories/:id/edit
  def edit
    @transaction_category = scoped_category
    @parent_category_options = parent_category_options(excluding: @transaction_category)
    authorize @transaction_category
  end

  # PATCH/PUT /transaction_categories/:id
  def update
    category = scoped_category
    authorize category
    result = TransactionCategoryUpdater.new.update_category(category: category, attributes: category_update_params)

    if result.updated?
      redirect_to transaction_categories_path, notice: "Category updated."
    else
      @transaction_category = result.category
      @parent_category_options = parent_category_options(excluding: result.category)
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /transaction_categories/:id
  def destroy
    category = scoped_category
    authorize category
    TransactionCategoryDiscarder.new.discard_category(category: category)

    redirect_to transaction_categories_path, notice: "Category deleted.", status: :see_other
  end

  private

  def category_params
    @category_params ||= params.expect(transaction_category: [ :name, :category_type, :parent_category_id, :icon_key, :color_hex, :hidden, :comment ])
  end

  def category_update_params
    params.expect(transaction_category: [ :name, :category_type, :parent_category_id, :icon_key, :color_hex, :hidden, :comment ])
  end

  def parent_category_for(category)
    parent_category_id = category_params[:parent_category_id]
    return if parent_category_id.blank?

    current_user.transaction_categories.kept.find(TransactionCategory.decode_prefix_id(parent_category_id) || parent_category_id)
  rescue ActiveRecord::RecordNotFound
    category.errors.add(:parent_category, "is unavailable")
    nil
  end

  def scoped_category
    policy_scope(TransactionCategory).kept.find(params[:id])
  end

  def next_display_order(parent_category = nil)
    current_user.transaction_categories.kept.where(parent_category: parent_category).maximum(:display_order).to_i + 1
  end

  def parent_category_options(excluding: nil)
    scope = current_user.transaction_categories.kept.order(:category_type, :display_order, :name)
    scope = scope.where.not(id: excluding.id) if excluding
    scope
  end

  def default_category_attributes
    {
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: next_display_order
    }
  end
end
