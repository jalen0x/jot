class TransactionTagsController < ApplicationController
  before_action :authenticate_user!

  # GET /transaction_tags/new
  def new
    @transaction_tag = current_user.transaction_tags.build(display_order: next_display_order)
    authorize @transaction_tag
    @transaction_tag_groups = tag_groups
  end

  # POST /transaction_tags
  def create
    authorize TransactionTag
    @transaction_tag = current_user.transaction_tags.build(tag_attributes)

    if @transaction_tag.save
      redirect_to transaction_tag_groups_path, notice: "Tag created."
    else
      @transaction_tag_groups = tag_groups
      render :new, status: :unprocessable_content
    end
  end

  private

  def tag_attributes
    attributes = tag_params
    attributes[:transaction_tag_group] = tag_group_for(attributes.delete(:transaction_tag_group_id))
    attributes.merge(display_order: next_display_order)
  end

  def tag_params
    params.expect(transaction_tag: [ :name, :transaction_tag_group_id ])
  end

  def tag_group_for(tag_group_id)
    return if tag_group_id.blank?

    current_user.transaction_tag_groups.kept.find(tag_group_id)
  end

  def tag_groups
    current_user.transaction_tag_groups.kept.order(:display_order, :name)
  end

  def next_display_order
    current_user.transaction_tags.kept.maximum(:display_order).to_i + 1
  end
end
