class TransactionPicturesController < ApplicationController
  before_action :authenticate_user!

  # DELETE /transactions/:transaction_id/pictures/:id
  def destroy
    transaction = policy_scope(Transaction).kept.find(params[:transaction_id])
    authorize transaction, :update?
    transaction.pictures.attachments.find(params[:id]).purge

    redirect_to transactions_path, notice: "Transaction picture removed."
  end
end
