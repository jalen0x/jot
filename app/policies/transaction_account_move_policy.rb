class TransactionAccountMovePolicy < ApplicationPolicy
  def create? = user.present?
end
