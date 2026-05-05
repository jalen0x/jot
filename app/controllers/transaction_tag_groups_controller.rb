class TransactionTagGroupsController < ApplicationController
  before_action :authenticate_user!

  # GET /transaction_tag_groups
  def index
    authorize TransactionTagGroup
    @transaction_tag_groups = policy_scope(TransactionTagGroup).kept.includes(:transaction_tags).order(:display_order, :name)
    @ungrouped_tags = policy_scope(TransactionTag).kept.where(transaction_tag_group_id: nil).order(:display_order, :name)
  end

  # GET /transaction_tag_groups/new
  def new
    @transaction_tag_group = current_user.transaction_tag_groups.build(display_order: next_display_order)
    authorize @transaction_tag_group
  end

  # POST /transaction_tag_groups
  def create
    authorize TransactionTagGroup
    @transaction_tag_group = current_user.transaction_tag_groups.build(tag_group_params.merge(display_order: next_display_order))

    if @transaction_tag_group.save
      redirect_to transaction_tag_groups_path, notice: "Tag group created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # GET /transaction_tag_groups/:id/edit
  def edit
    @transaction_tag_group = scoped_tag_group
    authorize @transaction_tag_group
  end

  # PATCH/PUT /transaction_tag_groups/:id
  def update
    tag_group = scoped_tag_group
    authorize tag_group

    if tag_group.update(tag_group_update_params)
      redirect_to transaction_tag_groups_path, notice: "Tag group updated."
    else
      @transaction_tag_group = tag_group
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /transaction_tag_groups/:id
  def destroy
    tag_group = scoped_tag_group
    authorize tag_group
    TransactionTagGroupDiscarder.new.discard_tag_group(tag_group: tag_group)

    redirect_to transaction_tag_groups_path, notice: "Tag group deleted.", status: :see_other
  end

  private

  def tag_group_params
    params.expect(transaction_tag_group: [ :name ])
  end

  def tag_group_update_params
    params.expect(transaction_tag_group: [ :name ])
  end

  def scoped_tag_group
    policy_scope(TransactionTagGroup).kept.find(params[:id])
  end

  def next_display_order
    current_user.transaction_tag_groups.kept.maximum(:display_order).to_i + 1
  end
end
