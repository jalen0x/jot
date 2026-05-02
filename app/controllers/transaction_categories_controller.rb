class TransactionCategoriesController < ApplicationController
  before_action :authenticate_user!

  # GET /transaction_categories
  def index
    authorize TransactionCategory
    @transaction_categories = policy_scope(TransactionCategory).kept.where(parent_category_id: nil).order(:category_type, :display_order, :name)
  end

  # GET /transaction_categories/new
  def new
    @transaction_category = current_user.transaction_categories.build(default_category_attributes)
    authorize @transaction_category
  end

  # POST /transaction_categories
  def create
    authorize TransactionCategory
    @transaction_category = current_user.transaction_categories.build(category_attributes)

    if @transaction_category.save
      redirect_to transaction_categories_path, notice: "Category created."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def category_attributes
    category_params.merge(display_order: next_display_order)
  end

  def category_params
    params.expect(transaction_category: [ :name, :category_type, :icon_key, :color_hex, :comment ])
  end

  def next_display_order
    current_user.transaction_categories.kept.where(parent_category_id: nil).maximum(:display_order).to_i + 1
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
