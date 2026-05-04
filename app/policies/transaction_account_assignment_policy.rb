class TransactionAccountAssignmentPolicy < ApplicationPolicy
  def create? = user.present?
end
