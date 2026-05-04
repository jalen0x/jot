class Api::V1::TransactionTagGroupsController < ApiController
  # GET /api/v1/transaction_tag_groups
  def index
    authorize TransactionTagGroup
    tag_groups = policy_scope(TransactionTagGroup).kept.order(:display_order, :name)

    render json: { transaction_tag_groups: tag_groups.map(&:as_json) }
  end

  # POST /api/v1/transaction_tag_groups
  def create
    authorize TransactionTagGroup
    tag_group = current_user.transaction_tag_groups.build(tag_group_params.merge(display_order: next_display_order))

    if tag_group.save
      render json: { transaction_tag_group: tag_group.as_json }, status: :created
    else
      render json: { errors: tag_group.errors.full_messages }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/v1/transaction_tag_groups/:id
  def update
    tag_group = scoped_tag_group
    authorize tag_group

    if tag_group.update(tag_group_params)
      render json: { transaction_tag_group: tag_group.as_json }
    else
      render json: { errors: tag_group.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/transaction_tag_groups/:id
  def destroy
    tag_group = scoped_tag_group
    authorize tag_group
    tag_group.discard!

    head :no_content
  end

  private

  def tag_group_params
    params.expect(transaction_tag_group: [ :name ])
  end

  def next_display_order
    current_user.transaction_tag_groups.kept.maximum(:display_order).to_i + 1
  end

  def scoped_tag_group
    policy_scope(TransactionTagGroup).kept.find(params[:id])
  end
end
