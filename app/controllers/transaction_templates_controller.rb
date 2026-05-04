class TransactionTemplatesController < ApplicationController
  before_action :authenticate_user!

  # GET /transaction_templates
  def index
    authorize TransactionTemplate
    @transaction_templates = policy_scope(TransactionTemplate).kept.includes(:account, :transaction_category, :transaction_tags).order(:template_kind, :display_order, :name)
  end

  # GET /transaction_templates/new
  def new
    @transaction_template = current_user.transaction_templates.build(default_template_attributes)
    authorize @transaction_template
    load_form_collections
  end

  # POST /transaction_templates
  def create
    authorize TransactionTemplate
    result = TransactionTemplateCreator.new.create_template(user: current_user, attributes: transaction_template_params, tag_ids: transaction_tag_ids)

    if result.created?
      redirect_to transaction_templates_path, notice: "Transaction template created."
    else
      @transaction_template = result.template
      load_form_collections
      render :new, status: :unprocessable_content
    end
  end

  # GET /transaction_templates/:id/edit
  def edit
    @transaction_template = scoped_transaction_template
    authorize @transaction_template
    load_form_collections
  end

  # PATCH/PUT /transaction_templates/:id
  def update
    transaction_template = scoped_transaction_template
    authorize transaction_template
    result = TransactionTemplateUpdater.new.update_template(template: transaction_template, attributes: transaction_template_params, tag_ids: transaction_tag_ids)

    if result.updated?
      redirect_to transaction_templates_path, notice: "Transaction template updated."
    else
      @transaction_template = result.template
      load_form_collections
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /transaction_templates/:id
  def destroy
    transaction_template = scoped_transaction_template
    authorize transaction_template
    transaction_template.discard!

    redirect_to transaction_templates_path, notice: "Transaction template deleted.", status: :see_other
  end

  private

  def transaction_template_params
    params.expect(transaction_template: [
      :template_kind,
      :transaction_kind,
      :name,
      :account_id,
      :destination_account_id,
      :transaction_category_id,
      :source_amount_cents,
      :destination_amount_cents,
      :hide_amount,
      :hidden,
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

  def scoped_transaction_template
    policy_scope(TransactionTemplate).kept.find(params[:id])
  end

  def default_template_attributes
    {
      template_kind: :normal,
      transaction_kind: :expense,
      source_amount_cents: 0,
      destination_amount_cents: 0,
      hide_amount: false,
      schedule_frequency: :disabled,
      schedule_rule: "",
      scheduled_at_minutes: 0,
      timezone_utc_offset_minutes: 0
    }
  end

  def load_form_collections
    @accounts = current_user.accounts.kept.order(:display_order, :name)
    @transaction_categories = current_user.transaction_categories.kept.order(:category_type, :display_order, :name)
    @transaction_tags = current_user.transaction_tags.kept.order(:display_order, :name)
  end
end
