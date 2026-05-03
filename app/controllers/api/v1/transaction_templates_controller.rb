class Api::V1::TransactionTemplatesController < ApiController
  # GET /api/v1/transaction_templates
  def index
    authorize TransactionTemplate
    templates = policy_scope(TransactionTemplate).kept.includes(:transaction_tags).order(:template_kind, :display_order, :name)

    render json: { transaction_templates: templates.map(&:as_json) }
  end

  # POST /api/v1/transaction_templates
  def create
    authorize TransactionTemplate
    result = TransactionTemplateCreator.new.create_template(
      user: current_user,
      attributes: transaction_template_params,
      tag_ids: transaction_tag_ids
    )

    if result.created?
      render json: { transaction_template: result.template.as_json }, status: :created
    else
      render json: { errors: result.template.errors.full_messages }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/v1/transaction_templates/:id
  def update
    template = scoped_template
    authorize template
    result = TransactionTemplateUpdater.new.update_template(
      template: template,
      attributes: transaction_template_params,
      tag_ids: transaction_tag_ids
    )

    if result.updated?
      render json: { transaction_template: result.template.as_json }
    else
      render json: { errors: result.template.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/transaction_templates/:id
  def destroy
    template = scoped_template
    authorize template
    template.discard!

    head :no_content
  end

  private

  def transaction_template_params
    @transaction_template_params ||= params.expect(transaction_template: [
      :template_kind,
      :transaction_kind,
      :name,
      :account_id,
      :destination_account_id,
      :transaction_category_id,
      :source_amount_cents,
      :destination_amount_cents,
      :hide_amount,
      :comment,
      :schedule_frequency,
      :schedule_rule,
      :schedule_start_on,
      :schedule_end_on,
      :scheduled_at_minutes,
      :timezone_utc_offset_minutes,
      transaction_tag_ids: []
    ])
  end

  def transaction_tag_ids
    Array(transaction_template_params[:transaction_tag_ids]).reject(&:blank?)
  end

  def scoped_template
    policy_scope(TransactionTemplate).kept.find(params[:id])
  end
end
