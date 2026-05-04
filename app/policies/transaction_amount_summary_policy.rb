class TransactionAmountSummaryPolicy < ApplicationPolicy
  def show? = user.present?
end
