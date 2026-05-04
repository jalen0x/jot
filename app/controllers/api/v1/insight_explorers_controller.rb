class Api::V1::InsightExplorersController < ApiController
  # GET /api/v1/insight_explorers
  def index
    authorize InsightExplorer
    explorers = policy_scope(InsightExplorer).kept.order(:display_order, :name)

    render json: { insight_explorers: explorers.map(&:as_json) }
  end

  # GET /api/v1/insight_explorers/:id
  def show
    explorer = scoped_explorer
    authorize explorer

    render json: { insight_explorer: explorer.as_json }
  end

  # POST /api/v1/insight_explorers
  def create
    authorize InsightExplorer
    explorer = current_user.insight_explorers.build(insight_explorer_attributes.except(:display_order).merge(display_order: next_display_order))

    if explorer.save
      render json: { insight_explorer: explorer.as_json }, status: :created
    else
      render json: { errors: explorer.errors.full_messages }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/v1/insight_explorers/:id
  def update
    explorer = scoped_explorer
    authorize explorer

    if explorer.update(insight_explorer_attributes)
      render json: { insight_explorer: explorer.as_json }
    else
      render json: { errors: explorer.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/insight_explorers/:id
  def destroy
    explorer = scoped_explorer
    authorize explorer
    explorer.discard!

    head :no_content
  end

  private

  def insight_explorer_params
    params.expect(insight_explorer: [ :name, :hidden, :display_order, { config: {} } ])
  end

  def insight_explorer_attributes
    insight_explorer_params.to_h.symbolize_keys
  end

  def next_display_order
    current_user.insight_explorers.kept.maximum(:display_order).to_i + 1
  end

  def scoped_explorer
    policy_scope(InsightExplorer).kept.find(params[:id])
  end
end
