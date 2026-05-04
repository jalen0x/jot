class InsightExplorersController < ApplicationController
  before_action :authenticate_user!

  # GET /insight_explorers
  def index
    authorize InsightExplorer
    @insight_explorers = policy_scope(InsightExplorer).kept.order(:display_order, :name)
  end

  # GET /insight_explorers/new
  def new
    authorize InsightExplorer
    @insight_explorer = current_user.insight_explorers.build(display_order: next_display_order, config: {})
    prepare_config_json
  end

  # POST /insight_explorers
  def create
    authorize InsightExplorer
    @insight_explorer = current_user.insight_explorers.build(insight_explorer_attributes.except(:display_order).merge(display_order: next_display_order))
    add_config_json_error

    if @insight_explorer.errors.empty? && @insight_explorer.save
      redirect_to insight_explorers_path, notice: t(".created")
    else
      prepare_config_json
      render :new, status: :unprocessable_content
    end
  end

  # GET /insight_explorers/:id/edit
  def edit
    @insight_explorer = scoped_explorer
    authorize @insight_explorer
    prepare_config_json
  end

  # PATCH/PUT /insight_explorers/:id
  def update
    @insight_explorer = scoped_explorer
    authorize @insight_explorer
    @insight_explorer.assign_attributes(insight_explorer_attributes)
    add_config_json_error

    if @insight_explorer.errors.empty? && @insight_explorer.save
      redirect_to insight_explorers_path, notice: t(".updated")
    else
      prepare_config_json
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /insight_explorers/:id
  def destroy
    explorer = scoped_explorer
    authorize explorer
    explorer.discard!

    redirect_to insight_explorers_path, notice: t(".deleted"), status: :see_other
  end

  private

  def insight_explorer_params
    params.expect(insight_explorer: [ :name, :hidden, :display_order, :config_json ])
  end

  def insight_explorer_attributes
    attributes = insight_explorer_params.to_h.symbolize_keys
    @config_json = attributes.delete(:config_json).presence || "{}"
    attributes[:config] = JSON.parse(@config_json)
    attributes
  rescue JSON::ParserError
    @config_json_invalid = true
    attributes[:config] = {}
    attributes
  end

  def add_config_json_error
    @insight_explorer.errors.add(:base, t("insight_explorers.form.config_json_invalid")) if @config_json_invalid
  end

  def prepare_config_json
    @config_json ||= JSON.pretty_generate(@insight_explorer.config.presence || {})
  end

  def next_display_order
    current_user.insight_explorers.kept.maximum(:display_order).to_i + 1
  end

  def scoped_explorer
    policy_scope(InsightExplorer).kept.find(params[:id])
  end
end
