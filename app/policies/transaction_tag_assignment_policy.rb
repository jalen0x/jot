class TransactionTagAssignmentPolicy < ApplicationPolicy
  def create? = user.present?
end
