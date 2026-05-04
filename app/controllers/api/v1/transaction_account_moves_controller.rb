class Api::V1::TransactionAccountMovesController < ApiController
  # POST /api/v1/transaction_account_moves
  def create
    authorize :transaction_account_move
    result = TransactionAccountMover.new.move_between_accounts(
      user: current_user,
      from_account: from_account,
      to_account: to_account
    )

    if result.moved?
      head :no_content
    else
      render json: { errors: result.errors }, status: :unprocessable_content
    end
  end

  private

  def from_account
    current_user.accounts.kept.find(Account.decode_prefix_id(from_account_id) || from_account_id)
  end

  def from_account_id
    params[:from_account_id].to_s
  end

  def to_account
    current_user.accounts.kept.find(Account.decode_prefix_id(to_account_id) || to_account_id)
  end

  def to_account_id
    params[:to_account_id].to_s
  end
end
