class Api::V1::TransactionTagsController < ApiController
  # GET /api/v1/transaction_tags
  def index
    authorize TransactionTag
    tags = policy_scope(TransactionTag).kept.order(:display_order, :name)

    render json: { transaction_tags: tags.map(&:as_json) }
  end

  # POST /api/v1/transaction_tags
  def create
    authorize TransactionTag
    tag = current_user.transaction_tags.build(tag_params.except(:transaction_tag_group_id))
    tag.transaction_tag_group = tag_group_for(tag)
    tag.display_order = next_display_order

    if tag.errors.empty? && tag.save
      render json: { transaction_tag: tag.as_json }, status: :created
    else
      render json: { errors: tag.errors.full_messages }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/v1/transaction_tags/:id
  def update
    tag = scoped_tag
    authorize tag
    result = TransactionTagUpdater.new.update_tag(tag: tag, attributes: tag_params)

    if result.updated?
      render json: { transaction_tag: result.tag.as_json }
    else
      render json: { errors: result.tag.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/transaction_tags/:id
  def destroy
    tag = scoped_tag
    authorize tag
    tag.discard!

    head :no_content
  end

  private

  def tag_params
    @tag_params ||= params.expect(transaction_tag: [ :name, :transaction_tag_group_id, :hidden ])
  end

  def tag_group_for(tag)
    tag_group_id = tag_params[:transaction_tag_group_id]
    return if tag_group_id.blank?

    current_user.transaction_tag_groups.kept.find(TransactionTagGroup.decode_prefix_id(tag_group_id) || tag_group_id)
  rescue ActiveRecord::RecordNotFound
    tag.errors.add(:transaction_tag_group, "is unavailable")
    nil
  end

  def next_display_order
    current_user.transaction_tags.kept.maximum(:display_order).to_i + 1
  end

  def scoped_tag
    policy_scope(TransactionTag).kept.find(params[:id])
  end
end
